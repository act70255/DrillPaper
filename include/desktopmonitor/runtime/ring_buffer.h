#pragma once

namespace desktopmonitor::runtime {

template <typename T, unsigned __int64 kCapacity>
class RingBuffer final {
    static_assert(kCapacity > 0, "RingBuffer capacity must be greater than zero.");

public:
    unsigned __int64 Size() const { return size_; }
    unsigned __int64 Capacity() const { return kCapacity; }

    void Push(const T& value) {
        values_[nextWrite_] = value;
        nextWrite_ = (nextWrite_ + 1) % kCapacity;
        if (size_ < kCapacity) {
            ++size_;
        }
    }

    bool TryGetOldest(unsigned __int64 offset, T* value) const {
        if (value == nullptr || offset >= size_) {
            return false;
        }
        const unsigned __int64 first = (nextWrite_ + kCapacity - size_) % kCapacity;
        *value = values_[(first + offset) % kCapacity];
        return true;
    }

private:
    T values_[kCapacity]{};
    unsigned __int64 nextWrite_ = 0;
    unsigned __int64 size_ = 0;
};

} // namespace desktopmonitor::runtime
