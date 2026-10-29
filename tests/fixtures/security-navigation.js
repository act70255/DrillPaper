import { DrillPaperClient } from './desktop-monitor-sdk.js';
/** 先重現拒絕 worker，再驗證外部導覽後可繼續或安全回復。
 * Returns:
 *     建立探針及完成第一個訂閱的 Promise。
 */
async function runNavigationProbe() {
  const client = new DrillPaperClient(window.chrome.webview);
  await client.ready();
  await new Promise(resolve => {
    try {
      const worker = new Worker('./worker.js');
      worker.onerror = event => { event.preventDefault(); resolve(); };
    } catch (error) {
      if (error.name !== 'SecurityError') throw error;
      resolve();
    }
  });
  await client.subscribe({ metrics: ['cpu'], intervalMs: 1000 });
  setTimeout(() => { location.href = '__BASE__/navigate'; }, 300);
  // 原頁面仍可運作時必須再次回報；若被換成錯誤頁則由宿主回復可信主題。
  setTimeout(() => client.subscribe({ metrics: ['cpu'], intervalMs: 1000 }), 1500);
}
runNavigationProbe().catch(error => console.error(error));
