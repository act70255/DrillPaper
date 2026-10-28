#pragma once
#include <functional>
#include <chrono>
#include <condition_variable>
#include <exception>
#include <mutex>
#include <thread>
#include <utility>
#include "desktopmonitor/core/metrics_snapshot.h"

namespace desktopmonitor::runtime {
class SamplingWorker final {
public:
    using Collect = std::function<core::MetricsSnapshot(bool)>;
    using Publish = std::function<void(const core::MetricsSnapshot&, unsigned long long)>;
    using Failure = std::function<void(std::exception_ptr)>;
    /** 建立可停止的採樣工作者。
     * Args:
     *     collect: 接受重設基準旗標的採集函數。
     *     publish: 收到新快照的函數。
     *     failure: 採集或傳送失敗的通知；不可呼叫 UI API。
     */
    SamplingWorker(Collect collect, Publish publish, Failure failure = {})
        : collect_(std::move(collect)), publish_(std::move(publish)), failure_(std::move(failure)),
          thread_([this] { Run(); }) {}
    /** 由擁有者執行緒停止並回收工作者；不可於 callback 內解構。 */
    ~SamplingWorker() { Stop(); }
    SamplingWorker(const SamplingWorker&) = delete;
    SamplingWorker& operator=(const SamplingWorker&) = delete;
    /** 設定採樣間隔，0 表示暫停。
     * Args:
     *     milliseconds: 採樣間隔。
     *     reset: 是否要求重設差分基準。
     * Returns:
     *     設定世代；可供 UI 拒絕先前狀態排隊中的舊快照。
     */
    unsigned long long Configure(unsigned milliseconds, bool reset) {
        unsigned long long generation;
        {
            std::lock_guard guard(mutex_);
            if (stopped_) return generation_;
            interval_ = milliseconds;
            reset_ = reset_ || reset;
            ++generation_;
            generation = generation_;
        }
        changed_.notify_all();
        return generation;
    }
    /** 停止工作者，並等待所有 callback 返回。 */
    void Stop() {
        {
            std::lock_guard guard(mutex_);
            stopped_ = true;
        }
        changed_.notify_all();
        if (thread_.joinable()) thread_.join();
    }
private:
    /** 在背景依設定採樣；callback 執行時不持有工作者鎖。 */
    void Run() {
        std::unique_lock lock(mutex_);
        try {
            while (!stopped_) {
                changed_.wait(lock, [this] { return stopped_ || interval_ != 0; });
                if (stopped_) break;
                const auto generation = generation_;
                const bool reset = std::exchange(reset_, false);
                lock.unlock();
                const auto snapshot = collect_(reset);
                lock.lock();
                if (stopped_) break;
                if (generation == generation_ && interval_ != 0) {
                    lock.unlock();
                    publish_(snapshot, generation);
                    lock.lock();
                }
                if (stopped_) break;
                // 從本次完成後等待，不追趕休眠期間的過期採樣。
                changed_.wait_for(lock, std::chrono::milliseconds(interval_),
                    [this, generation] { return stopped_ || generation_ != generation; });
            }
        } catch (...) {
            const auto error = std::current_exception();
            if (!lock.owns_lock()) lock.lock();
            stopped_ = true;
            lock.unlock();
            try { if (failure_) failure_(error); } catch (...) { }
        }
    }
    Collect collect_;
    Publish publish_;
    Failure failure_;
    std::mutex mutex_;
    std::condition_variable changed_;
    unsigned interval_ = 0;
    unsigned long long generation_ = 0;
    bool reset_ = true;
    bool stopped_ = false;
    std::thread thread_;
};
}
