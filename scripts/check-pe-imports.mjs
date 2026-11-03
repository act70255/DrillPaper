/**
 * 檢查 Windows PE 執行檔／DLL 的匯入（含 delay-load），確認沒有依賴 VC++ 執行環境。
 *
 * 用法：node scripts/check-pe-imports.mjs <檔案> [<檔案> ...]
 * 結束碼：0 表示全部沒有 VC++／UCRT 動態依賴；1 表示有依賴或檔案無法解析。
 */
import { readFileSync } from 'node:fs';
import { pathToFileURL } from 'node:url';

/** 需要隨附 VC++ 可轉散發套件或 UCRT 的 DLL 名稱規則。 */
const FORBIDDEN = [
    /^vcruntime\d+(_\d+)?d?\.dll$/i, /^msvcp\d+.*\.dll$/i, /^concrt\d+d?\.dll$/i, /^vcomp\d+d?\.dll$/i,
    /^api-ms-win-crt-.*\.dll$/i, /^ucrtbased?\.dll$/i,
];
/** PE32+ 資料目錄索引。 */
const IMPORT_DIRECTORY = 1;
const DELAY_IMPORT_DIRECTORY = 13;

/**
 * 解析 PE32+ 標頭與區段，提供資料目錄及 RVA 轉換。
 *
 * Args:
 *     buffer: 整個 PE 檔內容。
 *
 * Returns:
 *     含 directory(index)、toOffset(rva)、imageBase 的物件。
 *
 * Throws:
 *     Error: 不是 PE32+ 檔案或結構無法解析時。
 */
function parsePe(buffer) {
    if (buffer.length < 0x40 || buffer.readUInt16LE(0) !== 0x5a4d) throw new Error('不是有效的 PE 檔（缺少 MZ 標頭）。');
    const pe = buffer.readUInt32LE(0x3c);
    if (pe + 24 > buffer.length || buffer.readUInt32LE(pe) !== 0x00004550) throw new Error('不是有效的 PE 檔（缺少 PE 簽章）。');
    const sectionCount = buffer.readUInt16LE(pe + 6);
    const optionalSize = buffer.readUInt16LE(pe + 20);
    const optional = pe + 24;
    if (buffer.readUInt16LE(optional) !== 0x20b) throw new Error('只支援 x64（PE32+）檔案。');
    const directoryCount = buffer.readUInt32LE(optional + 108);
    const sections = [];
    for (let i = 0; i < sectionCount; i++) {
        const at = optional + optionalSize + i * 40;
        sections.push({ va: buffer.readUInt32LE(at + 12), size: Math.max(buffer.readUInt32LE(at + 8), buffer.readUInt32LE(at + 16)), raw: buffer.readUInt32LE(at + 20) });
    }
    return {
        imageBase: buffer.readBigUInt64LE(optional + 24),
        directory: (index) => (index < directoryCount ? buffer.readUInt32LE(optional + 112 + index * 8) : 0),
        toOffset: (rva) => {
            const section = sections.find((s) => rva >= s.va && rva < s.va + s.size);
            if (!section) throw new Error(`RVA 0x${rva.toString(16)} 不在任何區段內。`);
            return rva - section.va + section.raw;
        },
    };
}

/**
 * 讀取以 0 結尾的 ASCII 名稱。
 *
 * Args:
 *     buffer: PE 檔內容。
 *     offset: 名稱的檔案位移。
 *
 * Returns:
 *     名稱字串。
 */
function readName(buffer, offset) {
    return buffer.toString('latin1', offset, buffer.indexOf(0, offset));
}

/**
 * 讀取 PE 檔一般匯入表中的 DLL 名稱。
 *
 * Args:
 *     buffer: 整個 PE 檔內容。
 *
 * Returns:
 *     匯入的 DLL 名稱陣列（保持檔案中的大小寫）。
 *
 * Throws:
 *     Error: 不是 PE32+ 檔案或匯入表無法解析時。
 */
export function readImports(buffer) {
    const pe = parsePe(buffer);
    const names = [];
    const rva = pe.directory(IMPORT_DIRECTORY);
    if (rva === 0) return names;
    for (let entry = pe.toOffset(rva); ; entry += 20) {
        const nameRva = buffer.readUInt32LE(entry + 12);
        if (nameRva === 0) break;
        names.push(readName(buffer, pe.toOffset(nameRva)));
    }
    return names;
}

/**
 * 讀取 PE 檔 delay-load 匯入表中的 DLL 名稱。
 *
 * Args:
 *     buffer: 整個 PE 檔內容。
 *
 * Returns:
 *     延遲載入的 DLL 名稱陣列。
 *
 * Throws:
 *     Error: 不是 PE32+ 檔案或匯入表無法解析時。
 */
export function readDelayImports(buffer) {
    const pe = parsePe(buffer);
    const names = [];
    const rva = pe.directory(DELAY_IMPORT_DIRECTORY);
    if (rva === 0) return names;
    for (let entry = pe.toOffset(rva); ; entry += 32) {
        const attributes = buffer.readUInt32LE(entry);
        let nameRva = buffer.readUInt32LE(entry + 4);
        if (nameRva === 0) break;
        // 舊式描述元（attributes 未設 RVA 位元）存的是 VA，需扣掉 ImageBase。
        if ((attributes & 1) === 0) nameRva = Number(BigInt(nameRva) - pe.imageBase);
        names.push(readName(buffer, pe.toOffset(nameRva)));
    }
    return names;
}

/**
 * 從匯入名稱中挑出 VC++／UCRT 動態依賴。
 *
 * Args:
 *     imports: 匯入 DLL 名稱。
 *
 * Returns:
 *     違規的 DLL 名稱陣列。
 */
export function forbiddenImports(imports) {
    return imports.filter((name) => FORBIDDEN.some((pattern) => pattern.test(name)));
}

// 以 pathToFileURL 比對，含空白或非 ASCII 字元的路徑也能正確判斷為主程式。
if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
    const targets = process.argv.slice(2);
    let failed = targets.length === 0;
    if (failed) console.error('錯誤：請指定要檢查的 EXE 或 DLL 路徑。');
    for (const target of targets) {
        try {
            const buffer = readFileSync(target);
            const imports = [...readImports(buffer), ...readDelayImports(buffer)];
            const bad = forbiddenImports(imports);
            console.log(`${target}：匯入 ${imports.join(', ')}`);
            if (bad.length > 0) {
                console.error(`錯誤：${target} 仍依賴 VC++／UCRT 執行環境：${bad.join(', ')}`);
                failed = true;
            }
        } catch (error) {
            console.error(`錯誤：無法檢查 ${target} 的匯入表：${error.message}`);
            failed = true;
        }
    }
    if (failed) process.exit(1);
    console.log('PASS：沒有 VC++／UCRT 動態依賴（含 delay-load）。');
}
