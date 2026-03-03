import PBXProj
import ToolCommon

extension Generator {
    struct CreateCreateLinkDependenciesBuildPhaseObject {
        private let callable: Callable

        /// - Parameters:
        ///   - callable: The function that will be called in
        ///     `callAsFunction()`.
        init(callable: @escaping Callable = Self.defaultCallable) {
            self.callable = callable
        }

        /// Creates the "Create Link Dependencies" build phase object for a
        /// target.
        func callAsFunction(
            subIdentifier: Identifiers.Targets.SubIdentifier,
            hasCompileStub: Bool,
            isStaticLibrary: Bool
        ) -> Object {
            return callable(
                /*subIdentifier:*/ subIdentifier,
                /*hasCompileStub:*/ hasCompileStub,
                /*isStaticLibrary:*/ isStaticLibrary
            )
        }
    }
}

// MARK: - CreateCreateLinkDependenciesBuildPhaseObject.Callable

extension Generator.CreateCreateLinkDependenciesBuildPhaseObject {
    typealias Callable = (
        _ subIdentifier: Identifiers.Targets.SubIdentifier,
        _ hasCompileStub: Bool,
        _ isStaticLibrary: Bool
    ) -> Object

    static func defaultCallable(
        subIdentifier: Identifiers.Targets.SubIdentifier,
        hasCompileStub: Bool,
        isStaticLibrary: Bool
    ) -> Object {
        let action = #"""
perl -pe 's/\$(\()?([a-zA-Z_]\w*)(?(1)\))/$ENV{$2}/g' \
  "$SCRIPT_INPUT_FILE_0" > "$SCRIPT_OUTPUT_FILE_0"
"""#
        var shellScriptComponents: [String] = [
            #"""
set -euo pipefail

if [[ "${RULES_XCODEPROJ_ENABLE_PREVIEWS:-}" == "YES" ]]; then
\#(action)
else
touch "$SCRIPT_OUTPUT_FILE_0"
fi

"""#,
        ]

        if isStaticLibrary {
            // Write a .deps sidecar file for the libtool wrapper. The libtool
            // wrapper merges these dependency archives into the output .a after
            // creating it, so the JIT linker finds all symbols.
            shellScriptComponents.append(#"""
if [[ "${RULES_XCODEPROJ_ENABLE_PREVIEWS:-}" == "YES" && \
      -s "$SCRIPT_OUTPUT_FILE_0" ]]; then
  deps_file="$TARGET_BUILD_DIR/$EXECUTABLE_PATH.deps"
  dep_libs=()
  total_candidates=0
  skipped_candidates=0
  while IFS= read -r line; do
    if [[ -n "$line" && "$line" != -* ]]; then
      total_candidates=$((total_candidates + 1))
      clean="${line//\'/}"
      if [[ -f "$clean" ]]; then
        dep_libs+=("$clean")
      else
        skipped_candidates=$((skipped_candidates + 1))
        if (( skipped_candidates <= 3 )); then
          echo "note: .deps: file not found: $clean" >&2
        fi
      fi
    fi
  done < "$SCRIPT_OUTPUT_FILE_0"
  if (( skipped_candidates > 3 )); then
    echo "note: .deps: ... and $((skipped_candidates - 3)) more not found (of $total_candidates total)" >&2
  fi
  if (( ${#dep_libs[@]} > 0 )); then
    printf '%s\n' "${dep_libs[@]}" > "$deps_file"
  else
    rm -f "$deps_file"
    if (( total_candidates > 0 )); then
      echo "warning: .deps: no dependency archives found ($total_candidates candidates, $skipped_candidates missing)" >&2
    fi
  fi
else
  rm -f "$TARGET_BUILD_DIR/$EXECUTABLE_PATH.deps"
fi

"""#)
        }

        var outputPaths = [#"""
				"$(DERIVED_FILE_DIR)/link.params",
"""#]
        if hasCompileStub {
            outputPaths.append(#"""
				"$(DERIVED_FILE_DIR)/_CompileStub_.m",
"""#)
            shellScriptComponents.append(#"""
touch "$SCRIPT_OUTPUT_FILE_1"

"""#)
        }

        // The tabs for indenting are intentional.
        // Static library targets need alwaysOutOfDate so the .deps sidecar
        // is recreated every build (copy_outputs.sh re-copies the Bazel .a).
        let alwaysOutOfDate = isStaticLibrary
            ? "\n\t\t\talwaysOutOfDate = 1;"
            : ""
        let content = #"""
{
			isa = PBXShellScriptBuildPhase;\#(alwaysOutOfDate)
			buildActionMask = 2147483647;
			files = (
			);
			inputPaths = (
				"$(LINK_PARAMS_FILE)",
			);
			name = "Create Link Dependencies";
			outputPaths = (
\#(outputPaths.joined(separator: "\n"))
			);
			runOnlyForDeploymentPostprocessing = 0;
			shellPath = /bin/sh;
			shellScript = \#(
    shellScriptComponents.joined(separator: "\n").pbxProjEscaped
);
			showEnvVarsInLog = 0;
		}
"""#

        return Object(
            identifier: Identifiers.Targets.buildPhase(
                .createLinkDependencies,
                subIdentifier: subIdentifier
            ),
            content: content
        )
    }
}
