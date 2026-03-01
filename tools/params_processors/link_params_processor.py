#!/usr/bin/python3

import json
import sys
from typing import List


# linker flags that we don't want to propagate to Xcode.
# The values are the number of flags to skip, 1 being the flag itself, 2 being
# another flag right after it, etc.
_LD_SKIP_OPTS = {
    # Xcode sets the output path
    "-o": 2,

    # Xcode sets these, and no way to unset it
    "-bundle": 2,
    "-dynamiclib": 1,
    "-e": 2,
    "-isysroot": 2,
    "-static": 1,
    "-target": 2,

    # Xcode sets this, even if `CLANG_LINK_OBJC_RUNTIME = NO` is set
    "-fobjc-link-runtime": 1,

    # This is wrapped_clang specific, and we don't want to translate it for BwX
    "-Wl,-oso_prefix,__BAZEL_EXECUTION_ROOT__/": 1,
    "OSO_PREFIX_MAP_PWD": 1,

    "-ObjC": 1,
    "-headerpad_max_install_names": 1,
    "-no-canonical-prefixes": 1,
    "-objc_abi_version": 1,
}

_XLINKER_SKIP_FLAGS = {
    "-objc_abi_version",
    "-no_deduplicate",
}

_WL_SKIP_PREFIXES = (
    "-Wl,-objc_abi_version,",
    "-Wl,-no_warn_duplicate_libraries",
)


def _parse_args(args_files: List[str]) -> List[str]:
    args = []
    for args_path in args_files:
        # Each argument is a path to a file containing the actual arguments
        with open(args_path, encoding = "utf-8") as fp:
            lines = fp.read().splitlines()
            if lines[0].startswith("@"):
                # Sometimes those arguments might be also be a redirect
                with open(lines[0][1:], encoding = "utf-8") as f:
                    args.extend(f.read().splitlines())
            else:
                # First argument is the tool name
                args.extend(lines[1:])

    return args

def _quote_if_needed(opt: str) -> str:
    if " " in opt or ("$(" in opt and ")" in opt):
        return f"'{opt}'"
    return opt


def _normalize_path(opt: str) -> str:
    """Replace relative bazel-out/ paths and Bazel placeholder paths."""
    opt = opt.replace("bazel-out/", "$(BAZEL_OUT)/")
    opt = opt.replace("__BAZEL_XCODE_DEVELOPER_DIR__", "$(DEVELOPER_DIR)")
    opt = opt.replace("__BAZEL_XCODE_SDKROOT__", "$(SDKROOT)")
    return opt


def _process_linkopts(
        linkopts: List[str],
        is_framework: bool,
        generated_product_paths: List[str]
    ) -> List[str]:
    def _process_filelist(filelist_path: str) -> List[str]:
        with open(filelist_path, encoding = "utf-8") as fp:
            paths = fp.read().splitlines()

        return [
            _quote_if_needed(_normalize_path(path))
            for path in paths
            if not path in generated_product_paths and not path.endswith(".o")
        ]

    processed_linkopts = []
    def _quote_and_append_processed_linkopt(opt):
        processed_linkopts.append(_quote_if_needed(opt))

    last_opt = None
    def _process_linkopt(opt):
        if opt == "-filelist":
            return
        if last_opt == "-filelist":
            # Not calling `_quote_and_append_processed_linkopt`, because
            # `_process_filelist` applies quoting if needed
            processed_linkopts.extend(_process_filelist(opt))
            return

        # Handle -Xlinker pairs: skip specific ld64 flags, and skip bare
        # numeric values (orphaned from previously-skipped flags)
        if last_opt == "-Xlinker":
            if opt in _XLINKER_SKIP_FLAGS or opt.isdigit():
                return
            _quote_and_append_processed_linkopt("-Xlinker")
            _quote_and_append_processed_linkopt(_normalize_path(opt))
            return
        if opt == "-Xlinker":
            return

        opt_generated_path_matches = [
            path
            for path in generated_product_paths
            if opt.endswith(path)
        ]
        if opt_generated_path_matches:
            if last_opt == "-force_load":
                processed_linkopts.pop()
            return

        # Xcode sets entitlements
        if opt.startswith("-Wl,-sectcreate,__TEXT,__entitlements,"):
            return

        # Xcode sets Info.plist
        if opt.startswith("-Wl,-sectcreate,__TEXT,__info_plist,"):
            return

        # Xcode adds object files
        if opt.endswith(".o"):
            return

        # We don't want the BwB swizzle fix for BwX mode
        if opt.endswith("/libswizzle_absolute_xcttestsourcelocation.a"):
            if last_opt == "-force_load":
                processed_linkopts.pop()
            return

        # These flags are for wrapped_clang only
        if (opt.startswith("DSYM_HINT_DSYM_PATH=") or
            opt.startswith("DSYM_HINT_LINKED_BINARY=")):
            return

        for prefix in _WL_SKIP_PREFIXES:
            if opt.startswith(prefix):
                return

        # Convert -Wl, flags to -Xlinker pairs
        if opt.startswith("-Wl,"):
            parts = opt[4:].split(",")
            for part in parts:
                _quote_and_append_processed_linkopt("-Xlinker")
                _quote_and_append_processed_linkopt(part)
            return

        if opt == "-lc++":
            return

        opt = _normalize_path(opt)

        _quote_and_append_processed_linkopt(opt)

    skip_next = 0
    for linkopt in linkopts:
        if skip_next:
            skip_next -= 1
            continue

        # Change "link.params" from `shell` to `multiline` format
        # https://bazel.build/versions/6.1.0/rules/lib/Args#set_param_file_format.format
        if linkopt.startswith("'") and linkopt.endswith("'"):
            linkopt = linkopt[1:-1]

        skip_next = _LD_SKIP_OPTS.get(linkopt, 0)
        if skip_next:
            skip_next -= 1
            continue

        _process_linkopt(linkopt)
        last_opt = linkopt

    return processed_linkopts


def _main(
        output_path: str,
        generated_product_paths_file: str,
        is_framework: bool,
        args_files: List[str]
    ) -> None:
    with open(generated_product_paths_file, encoding = "utf-8") as fp:
        generated_product_paths = json.load(fp)

    linkopts = _process_linkopts(
        linkopts = _parse_args(args_files),
        is_framework = is_framework,
        generated_product_paths = generated_product_paths,
    )

    with open(output_path, encoding = "utf-8", mode = "w") as fp:
        result = "\n".join(linkopts)
        fp.write(f'{result}\n')


if __name__ == "__main__":
    if len(sys.argv) < 5:
        print(
            f"""
Usage: {sys.argv[0]} <output> <self_linked_outputs_file> <is_framework> \
<args_files...>\
""",
            file = sys.stderr,
        )
        exit(1)

    _main(
        sys.argv[1],
        sys.argv[2],
        sys.argv[3] == "1",
        sys.argv[4:],
    )
