#include "desktopmonitor/runtime/ring_buffer.h"

using desktopmonitor::runtime::RingBuffer;

extern "C" int TestEntry() {
    RingBuffer<int, 3> values;
    if (values.Size() != 0 || values.Capacity() != 3) {
        return 1;
    }

    values.Push(10);
    values.Push(20);
    values.Push(30);
    values.Push(40);
    if (values.Size() != 3) {
        return 2;
    }

    int value = 0;
    if (!values.TryGetOldest(0, &value) || value != 20) {
        return 3;
    }
    if (!values.TryGetOldest(2, &value) || value != 40) {
        return 4;
    }
    if (values.TryGetOldest(3, &value)) {
        return 5;
    }
    return 0;
}
