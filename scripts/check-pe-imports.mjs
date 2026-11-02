/**
 * 檢查 Windows PE 執行檔的匯入 DLL，確認沒有依賴 VC++ 執行環境。
 *
 * 用法：node scripts/check-pe-imports.mjs <exe 路徑>
 * 結束碼：0 表示沒有 VC++／UCRT 動態依賴；1 表示有依賴或檔案格式錯誤。
 */
import { readFileSync } from 'node:fs';

/** 需要隨附 VC++ 可轉散發套件或 UCRT 的 DLL 名稱規則。 */
const FORBIDDEN = [/^vcruntime\d+(_\d+)?d?\.dll$/i, /^msvcp\d+.*\.dll$/i, /^api-ms-win-crt-.*\.dll$/i, /^ucrtbased?\.dll$/i];

/**
 * 讀取 PE 檔的匯入 DLL 名稱。
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
    if (buffer.readUInt16LE(0) !== 0x5a4d) throw new Error('不是有效的 PE 檔（缺少 MZ 標頭）。');
    const pe = buffer.readUInt32LE(0x3c);
    if (buffer.readUInt32LE(pe) !== 0x00004550) throw new Error('不是有效的 PE 檔（缺少 PE 簽章）。');
    const sectionCount = buffer.readUInt16LE(pe + 6);
    const optionalSize = buffer.readUInt16LE(pe + 20);
    const optional = pe + 24;
    if (buffer.readUInt16LE(optional) !== 0x20b) throw new Error('只支援 x64（PE32+）執行檔。');
    const importRva = buffer.readUInt32LE(optional + 120);
    const sections = [];
    for (let i = 0; i < sectionCount; i++) {
        const at = optional + optionalSize + i * 40;
        sections.push({ va: buffer.readUInt32LE(at + 12), size: Math.max(buffer.readUInt32LE(at + 8), buffer.readUInt32LE(at + 16)), raw: buffer.readUInt32LE(at + 20) });
    }
    const toOffset = (rva) => {
        const section = sections.find((s) => rva >= s.va && rva < s.va + s.size);
        if (!section) throw new Error(`RVA 0x${rva.toString(16)} 不在任何區段內。`);
        return rva - section.va + section.raw;
    };
    const names = [];
    if (importRva === 0) return names;
    for (let entry = toOffset(importRva); ; entry += 20) {
        const nameRva = buffer.readUInt32LE(entry + 12);
        if (nameRva === 0) break;
        const start = toOffset(nameRva);
        names.push(buffer.toString('latin1', start, buffer.indexOf(0, start)));
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

if (import.meta.url === `file:///${process.argv[1].replaceAll('\\', '/')}`.replace('file:////', 'file:///')) {
    const target = process.argv[2];
    try {
        if (!target) throw new Error('請指定要檢查的 EXE 路徑。');
        const imports = readImports(readFileSync(target));
        const bad = forbiddenImports(imports);
        console.log(`匯入 DLL：${imports.join(', ')}`);
        if (bad.length > 0) {
            console.error(`錯誤：執行檔仍依賴 VC++／UCRT 執行環境：${bad.join(', ')}`);
            process.exit(1);
        }
        console.log('PASS：沒有 VC++／UCRT 動態依賴。');
    } catch (error) {
        console.error(`錯誤：無法檢查匯入表：${error.message}`);
        process.exit(1);
    }
}
