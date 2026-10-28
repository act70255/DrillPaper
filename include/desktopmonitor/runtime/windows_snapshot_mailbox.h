#pragma once

#include <windows.h>

namespace desktopmonitor::runtime {

template <typename T>
class WindowsSnapshotMailbox final {
public:
    // Returns true only when the caller must post the one pending UI notification.
    bool Publish(const T& value) {
        ExclusiveLock guard(&lock_);
        latest_ = value;
        hasValue_ = true;
        if (notificationPending_) {
            return false;
        }
        notificationPending_ = true;
        return true;
    }

    bool TryTake(T* value) {
        if (value == nullptr) {
            return false;
        }
        ExclusiveLock guard(&lock_);
        if (!hasValue_) {
            notificationPending_ = false;
            return false;
        }
        *value = latest_;
        hasValue_ = false;
        notificationPending_ = false;
        return true;
    }

    void NotificationPostFailed() {
        ExclusiveLock guard(&lock_);
        notificationPending_ = false;
    }

private:
    class ExclusiveLock final {
    public:
        explicit ExclusiveLock(SRWLOCK* lock) : lock_(lock) {
            AcquireSRWLockExclusive(lock_);
        }
        ~ExclusiveLock() { ReleaseSRWLockExclusive(lock_); }
        ExclusiveLock(const ExclusiveLock&) = delete;
        ExclusiveLock& operator=(const ExclusiveLock&) = delete;

    private:
        SRWLOCK* lock_;
    };

    SRWLOCK lock_ = SRWLOCK_INIT;
    T latest_{};
    bool hasValue_ = false;
    bool notificationPending_ = false;
};

} // namespace desktopmonitor::runtime
