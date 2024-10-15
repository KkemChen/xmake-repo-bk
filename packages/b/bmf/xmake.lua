package("bmf")
    set_homepage("https://babitmf.github.io/")
    set_description("Cross-platform, customizable multimedia/video processing framework.  With strong GPU acceleration, heterogeneous design, multi-language support, easy to use, multi-framework compatible and high performance, the framework is ideal for transcoding, AI inference, algorithm integration, live video streaming, and more.")
    set_license("Apache-2.0")

    add_urls("https://github.com/KkemChen/bmf/archive/refs/tags/xmake_$(version).tar.gz", {alias = "git_release"})
    add_urls("https://github.com/KkemChen/bmf.git", {submodules = false, alias = "git"})
    add_urls(path.join(os.scriptdir(), "bmf-xmake_v1.0.0.tar.gz"), {alias = "local"})

    add_versions("git:latest", "a399ed6be0931fc40aec94f9f3849ba560262a67")
    add_versions("git_release:v1.0.0", "1a721116761683bac5d2ff72a098a594c37413625874301765ce294252c7d2fd")
    add_versions("local:v1.0.0", "1a721116761683bac5d2ff72a098a594c37413625874301765ce294252c7d2fd")
    add_patches("v1.0.0", path.join(os.scriptdir(), "patches", "0001-Modified-CMakeLists.txt-for-xmake.patch"), "259bd41c5083ab303403829e47730a615cdf79da9eb81c1339a423169177b31f")

    add_configs("breakpad", {description = "Enable build with breakpad support", default = false, type = "boolean"})
    add_configs("cuda", {description = "Enable CUDA support", default = false, type = "boolean"})
    add_configs("torch", {description = "Enable torch support", default = false, type = "boolean"})
    add_configs("python", {description = "Enable build with python support", default = true, type = "boolean"})
    add_configs("glog", {description = "Enable build with glog support", default = false, type = "boolean"})
    add_configs("ffmpeg", {description = "Enable build with ffmpeg support", default = true, type = "boolean"})
    add_configs("mobile", {description = "Enable build for mobile platform", default = false, type = "boolean"})
    add_configs("shared", {description = "Build shared library.", default = true, type = "boolean", readonly = true})

    add_deps("cmake")
    add_deps("nlohmann_json", {configs = {cmake = true}})
    add_deps("spdlog", {configs = {header_only = false, fmt_external = true}})
    add_deps("dlpack", "backward-cpp", "benchmark")
    add_deps("gtest", {configs = {main = true}})

    if is_plat("windows") then
        add_deps("dlfcn-win32")
    elseif is_plat("linux", "bsd") then
        add_syslinks("pthread", "dl")
    end
    
    on_check("windows", function (package)
        local vs_toolset = package:toolchain("msvc"):config("vs_toolset")
        if vs_toolset then
            local vs_toolset_ver = import("core.base.semver").new(vs_toolset)
            local minor = vs_toolset_ver:minor()
            assert(minor and minor >= 30, "package(bmf): Only support >= v143 toolset")
        end
    end)

    on_load(function (package)
        if package:config("breakpad") then
            package:add("deps", "breakpad")
        end
        if package:config("cuda") then
            package:add("deps", "cuda")
        end
        if package:config("torch") then
            -- package:add("deps", "cuda")
            -- TODO: add torch support
        end
        if package:config("python") then
            -- package:add("extsources", "python")
            package:add("deps", "python 3.x")
            package:add("deps", "pybind11 v2.6.2")
        end
        if package:config("glog") then
            package:add("deps", "glog")
        end
        if package:config("ffmpeg") then
            package:add("deps", "ffmpeg 4.x", {configs = {shared = true}})
        end
        if package:config("mobile") then
            package:add("deps", "benchmark")
        end

        if package:has_tool("cxx", "cl") then
            package:add("cxxflags", "/Zc:preprocessor")
        end
    end)

    on_install("windows", "linux", function (package)
        local configs = {
            "-DBMF_LOCAL_DEPENDENCIES=OFF",
            "-DBMF_ENABLE_TEST=OFF",
            "-DBMF_PYENV=",
        }
        table.insert(configs, "-DCMAKE_BUILD_TYPE=" .. (package:is_debug() and "Debug" or "Release"))
        table.insert(configs, "-DBUILD_SHARED_LIBS=" .. (package:config("shared") and "ON" or "OFF"))

        local ver = package:version() or "0.0.10"
        if ver then
            table.insert(configs, "-DBMF_BUILD_VERSION=" .. ver)
        end

        table.insert(configs, "-DBMF_ENABLE_BREAKPAD=" .. (package:config("breakpad") and "ON" or "OFF"))
        table.insert(configs, "-DBMF_ENABLE_CUDA=" .. (package:config("cuda") and "ON" or "OFF"))
        table.insert(configs, "-DBMF_ENABLE_TORCH=" .. (package:config("torch") and "ON" or "OFF"))
        table.insert(configs, "-DBMF_ENABLE_PYTHON=" .. (package:config("python") and "ON" or "OFF"))
        table.insert(configs, "-DBMF_ENABLE_GLOG=" .. (package:config("glog") and "ON" or "OFF"))
        table.insert(configs, "-DBMF_ENABLE_FFMPEG=" .. (package:config("ffmpeg") and "ON" or "OFF"))
        table.insert(configs, "-DBMF_ENABLE_MOBILE=" .. (package:config("mobile") and "ON" or "OFF"))

        local envs = import("package.tools.cmake").buildenvs(package)
        if package:is_plat("windows") then
            envs.SCRIPT_EXEC_MODE = "win"
        end
        -- import("package.tools.cmake").install(package, configs, {envs = envs})
        -- os.rm(package:installdir())
        for key, value in pairs(envs) do
            os.setenv(key, value)
        end
        os.setenv("CMAKE_ARGS", table.concat(configs, " "))
        os.rm("output")
        os.rm("build")
        os.execv("bash", {"./build.sh", "non_local", package:debug() and "debug" or ""})

        -- os.cp("bmf/c_modules/meta/BUILTIN_CONFIG.json", path.join(package:buildir(), "output/bmf"))
        -- os.cp(path.join(package:buildir(), "output/bmf"), package:installdir())

        local bmf_install_dir = package:installdir("bmf")
        os.cp("output/bmf", bmf_install_dir, {rootdir = "output/bmf"})
        for _, subdir in ipairs(os.dirs(path.join(bmf_install_dir, "*"))) do
            os.runv("ln", {"-s", path.absolute(subdir), package:installdir()})
        end
        os.runv("ln", {"-s", path.join(bmf_install_dir, "BUILTIN_CONFIG.json"), path.join(package:installdir(), "BUILTIN_CONFIG.json")})

        package:addenv("PATH", package:installdir("bin"))
        package:addenv("PYTHONPATH", package:installdir())
        package:addenv("PYTHONPATH", path.join(bmf_install_dir, "lib"))
    end)

    on_test(function (package)
        assert(package:check_cxxsnippets({test = [[
            void test() {
                bmf_sdk::AudioFrame x(0, 0);
            }
        ]]}, {configs = {languages = "c++20"}, includes = "bmf/sdk/audio_frame.h"}))
    end)