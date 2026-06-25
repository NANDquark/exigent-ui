import glob
import os
import subprocess


def batch_convert_to_fixed_size():
    edge_path = os.path.join(
        os.environ.get("ProgramFiles(x86)", "C:\\Program Files (x86)"),
        "Microsoft",
        "Edge",
        "Application",
        "msedge.exe",
    )

    if not os.path.exists(edge_path):
        edge_path = "msedge"

    svg_files = glob.glob("*.svg")
    size = 64

    for svg_file in svg_files:
        output_png = os.path.splitext(svg_file)[0] + ".png"
        in_path = "file://" + os.path.abspath(svg_file)
        out_path = os.path.abspath(output_png)

        cmd = [
            edge_path,
            "--headless",
            f"--screenshot={out_path}",
            f"--window-size={size},{size}",
            "--default-background-color=00000000",
            "--hide-scrollbars",
            "--force-device-scale-factor=1",
            in_path,
        ]

        try:
            subprocess.run(cmd, check=True, capture_output=True)
            print(f"✓ Resized to {size}x{size}: {svg_file}")
        except Exception:
            print(f"✗ Failed {svg_file}")


if __name__ == "__main__":
    batch_convert_to_fixed_size()
