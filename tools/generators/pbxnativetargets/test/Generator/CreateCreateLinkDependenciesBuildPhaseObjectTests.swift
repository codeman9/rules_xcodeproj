import CustomDump
import ToolCommon
import XCTest

@testable import pbxnativetargets
@testable import PBXProj

class CreateCreateLinkDependenciesBuildPhaseObjectTests: XCTestCase {
    func test_base() {
        // Arrange

        let subIdentifier = Identifiers.Targets.SubIdentifier(
            shard: "A_SHARD",
            hash: "A_HASH"
        )
        let hasCompileStub = false

        // The tabs for indenting are intentional
        let expectedObject = Object(
            identifier: #"""
A_SHARD00A_HASH000000000005 /* Create Link Dependencies */
"""#,
            content: #"""
{
			isa = PBXShellScriptBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			inputPaths = (
				"$(LINK_PARAMS_FILE)",
			);
			name = "Create Link Dependencies";
			outputPaths = (
				"$(DERIVED_FILE_DIR)/link.params",
			);
			runOnlyForDeploymentPostprocessing = 0;
			shellPath = /bin/sh;
			shellScript = "set -euo pipefail\n\nif [[ \"${RULES_XCODEPROJ_ENABLE_PREVIEWS:-}\" == \"YES\" ]]; then\nperl -pe 's/\\$(\\()?([a-zA-Z_]\\w*)(?(1)\\))/$ENV{$2}/g' \\\n  \"$SCRIPT_INPUT_FILE_0\" > \"$SCRIPT_OUTPUT_FILE_0\"\nelse\ntouch \"$SCRIPT_OUTPUT_FILE_0\"\nfi\n";
			showEnvVarsInLog = 0;
		}
"""#
        )

        // Act

        let object = Generator.CreateCreateLinkDependenciesBuildPhaseObject
            .defaultCallable(
                subIdentifier: subIdentifier,
                hasCompileStub: hasCompileStub,
                isStaticLibrary: false
            )

        // Assert

        XCTAssertNoDifference(object, expectedObject)
    }

    func test_hasCompileStub() {
        // Arrange

        let subIdentifier = Identifiers.Targets.SubIdentifier(
            shard: "A_SHARD",
            hash: "A_HASH"
        )
        let hasCompileStub = true

        // The tabs for indenting are intentional
        let expectedObject = Object(
            identifier: #"""
A_SHARD00A_HASH000000000005 /* Create Link Dependencies */
"""#,
            content: #"""
{
			isa = PBXShellScriptBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			inputPaths = (
				"$(LINK_PARAMS_FILE)",
			);
			name = "Create Link Dependencies";
			outputPaths = (
				"$(DERIVED_FILE_DIR)/link.params",
				"$(DERIVED_FILE_DIR)/_CompileStub_.m",
			);
			runOnlyForDeploymentPostprocessing = 0;
			shellPath = /bin/sh;
			shellScript = "set -euo pipefail\n\nif [[ \"${RULES_XCODEPROJ_ENABLE_PREVIEWS:-}\" == \"YES\" ]]; then\nperl -pe 's/\\$(\\()?([a-zA-Z_]\\w*)(?(1)\\))/$ENV{$2}/g' \\\n  \"$SCRIPT_INPUT_FILE_0\" > \"$SCRIPT_OUTPUT_FILE_0\"\nelse\ntouch \"$SCRIPT_OUTPUT_FILE_0\"\nfi\n\ntouch \"$SCRIPT_OUTPUT_FILE_1\"\n";
			showEnvVarsInLog = 0;
		}
"""#
        )

        // Act

        let object = Generator.CreateCreateLinkDependenciesBuildPhaseObject
            .defaultCallable(
                subIdentifier: subIdentifier,
                hasCompileStub: hasCompileStub,
                isStaticLibrary: false
            )

        // Assert

        XCTAssertNoDifference(object, expectedObject)
    }

    func test_staticLibrary() {
        // Arrange

        let subIdentifier = Identifiers.Targets.SubIdentifier(
            shard: "A_SHARD",
            hash: "A_HASH"
        )
        let hasCompileStub = false

        // The tabs for indenting are intentional
        let expectedObject = Object(
            identifier: #"""
A_SHARD00A_HASH000000000005 /* Create Link Dependencies */
"""#,
            content: #"""
{
			isa = PBXShellScriptBuildPhase;
			alwaysOutOfDate = 1;
			buildActionMask = 2147483647;
			files = (
			);
			inputPaths = (
				"$(LINK_PARAMS_FILE)",
			);
			name = "Create Link Dependencies";
			outputPaths = (
				"$(DERIVED_FILE_DIR)/link.params",
			);
			runOnlyForDeploymentPostprocessing = 0;
			shellPath = /bin/sh;
			shellScript = "set -euo pipefail\n\nif [[ \"${RULES_XCODEPROJ_ENABLE_PREVIEWS:-}\" == \"YES\" ]]; then\nperl -pe 's/\\$(\\()?([a-zA-Z_]\\w*)(?(1)\\))/$ENV{$2}/g' \\\n  \"$SCRIPT_INPUT_FILE_0\" > \"$SCRIPT_OUTPUT_FILE_0\"\nelse\ntouch \"$SCRIPT_OUTPUT_FILE_0\"\nfi\n\nif [[ \"${RULES_XCODEPROJ_ENABLE_PREVIEWS:-}\" == \"YES\" && \\\n      -s \"$SCRIPT_OUTPUT_FILE_0\" ]]; then\n  deps_file=\"$TARGET_BUILD_DIR/$EXECUTABLE_PATH.deps\"\n  dep_libs=()\n  while IFS= read -r line; do\n    [[ -n \"$line\" && \"$line\" != -* && -f \"${line//\\'/}\" ]] && \\\n      dep_libs+=(\"${line//\\'/}\")\n  done < \"$SCRIPT_OUTPUT_FILE_0\"\n  if (( ${#dep_libs[@]} > 0 )); then\n    printf '%s\\n' \"${dep_libs[@]}\" > \"$deps_file\"\n  else\n    rm -f \"$deps_file\"\n  fi\nelse\n  rm -f \"$TARGET_BUILD_DIR/$EXECUTABLE_PATH.deps\"\nfi\n";
			showEnvVarsInLog = 0;
		}
"""#
        )

        // Act

        let object = Generator.CreateCreateLinkDependenciesBuildPhaseObject
            .defaultCallable(
                subIdentifier: subIdentifier,
                hasCompileStub: hasCompileStub,
                isStaticLibrary: true
            )

        // Assert

        XCTAssertNoDifference(object, expectedObject)
    }
}
