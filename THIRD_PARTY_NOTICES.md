# Third-party notices

## Catch2

- Version: 3.8.1 (pinned Git tag `v3.8.1` in CMake FetchContent)
- Source: https://github.com/catchorg/Catch2
- License: Boost Software License 1.0 (BSL-1.0)
- Use: native unit-test executable only; not part of the application package.

The project does not redistribute Catch2 source or binaries in its release package. The selected release and CMake targets are documented by the [Catch2 CMake integration guide](https://github.com/catchorg/Catch2/blob/v3.8.1/docs/cmake-integration.md). The upstream repository identifies its license as BSL-1.0 and contains the license text in the same tagged source.

## Theme manager dependencies

- nlohmann/json 3.11.3, MIT, Copyright 2013–2022 Niels Lohmann: https://github.com/nlohmann/json/blob/v3.11.3/LICENSE.MIT
- miniz 3.0.2, MIT, Copyright 2013–2014 RAD Game Tools and Valve Software, Copyright 2010–2014 Rich Geldreich and Tenacious Software LLC: https://github.com/richgel999/miniz/blob/3.0.2/LICENSE

The native theme commands link these dependencies into the app. Complete upstream license texts are in `third_party/licenses/` and copied to the build's `resources/licenses/`.
