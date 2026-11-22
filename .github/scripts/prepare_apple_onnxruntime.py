import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
from urllib.parse import unquote, urljoin, urlparse


UPSTREAM = "https://github.com/masicai/onnxruntime-swift-package-manager"
VERSION = "1.28.0"
REVISION = "3fb68950a5967c8c120f9f99a1a850a43985a4c9"


def main():
    parser = argparse.ArgumentParser(description="Prepare a SwiftPM mirror for Apple CI")
    parser.add_argument("platform", choices=("ios", "macos"))
    platform = parser.parse_args().platform

    package_config = Path(".dart_tool/package_config.json").resolve()
    packages = json.loads(package_config.read_text(encoding="utf-8"))["packages"]
    plugin = next(package for package in packages if package["name"] == "flutter_onnxruntime")
    plugin_uri = urljoin(package_config.as_uri(), plugin["rootUri"])
    plugin_root = Path(unquote(urlparse(plugin_uri).path))
    plugin_manifest = plugin_root / platform / "flutter_onnxruntime" / "Package.swift"
    pinned_dependency = rf'\.package\(\s*url:\s*"{re.escape(UPSTREAM)}"\s*,\s*exact:\s*"{re.escape(VERSION)}"\s*\)'
    if not plugin_manifest.is_file() or not re.search(
        pinned_dependency, plugin_manifest.read_text(encoding="utf-8")
    ):
        print(f"ONNX Runtime Swift package {VERSION} is absent from {platform}. Skipping mirror setup.")
        return

    mirror_root = Path(tempfile.mkdtemp(prefix="onnxruntime-", dir=os.environ["RUNNER_TEMP"]))
    mirror = mirror_root / "onnxruntime-swift-package-manager"
    subprocess.run(["git", "init", "--quiet", str(mirror)], check=True)
    git = ["git", "-C", str(mirror)]
    subprocess.run([*git, "fetch", "--quiet", "--depth", "1", "--no-tags", UPSTREAM, REVISION], check=True)
    subprocess.run([*git, "checkout", "--quiet", "--detach", REVISION], check=True)

    # The plugin links the core runtime. Remove the unused archive that fails TLS verification.
    patch = Path(__file__).with_name("onnxruntime-swift-without-extensions.patch").resolve()
    subprocess.run([*git, "apply", str(patch)], check=True)
    timestamp = subprocess.check_output([*git, "show", "-s", "--format=%cI"], text=True).strip()
    subprocess.run(
        [*git, "-c", "user.name=MeshUSF CI", "-c", "user.email=ci@mesh-usf.invalid",
         "commit", "--quiet", "-m", "Omit unused ONNX Runtime SwiftPM extensions", "--", "Package.swift"],
        check=True,
        env={**os.environ, "GIT_AUTHOR_DATE": timestamp, "GIT_COMMITTER_DATE": timestamp},
    )
    subprocess.run([*git, "tag", VERSION], check=True)

    platform_dir = Path(platform)
    # Flutter and Xcode can resolve packages through either workspace.
    for workspace in (
        platform_dir / "Runner.xcworkspace",
        platform_dir / "Runner.xcodeproj/project.xcworkspace",
    ):
        mirror_config = workspace / "xcshareddata/swiftpm/configuration/mirrors.json"
        mirror_config.parent.mkdir(parents=True, exist_ok=True)
        config = {"version": 1, "object": []}
        if mirror_config.is_file():
            config = json.loads(mirror_config.read_text(encoding="utf-8"))
        config["object"] = [entry for entry in config["object"] if entry["original"] != UPSTREAM]
        config["object"].append({"original": UPSTREAM, "mirror": mirror.as_uri()})
        mirror_config.write_text(json.dumps(config, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
