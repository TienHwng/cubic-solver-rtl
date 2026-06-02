import math
import struct
import csv
import argparse
from pathlib import Path
import numpy as np


FP32_NAN = 0x7FC00000
BASE_DIR = Path(__file__).resolve().parent


def resolve_path(path_text):
    path = Path(path_text)
    if not path.is_absolute():
        path = BASE_DIR / path
    return path


def to_f32(x):
    return np.float32(x).item()


def f32_to_bits(x):
    return struct.unpack(">I", struct.pack(">f", np.float32(x)))[0]


def bits_to_f32(bits):
    return struct.unpack(">f", struct.pack(">I", bits & 0xFFFFFFFF))[0]


def f32_to_hex(x):
    return f"{f32_to_bits(x):08X}"


def real_cbrt(x):
    """
    Cube root that works for negative numbers.
    """
    if x >= 0:
        return abs(x) ** (1.0 / 3.0)
    else:
        return -((-x) ** (1.0 / 3.0))


def cubic_solver_golden(a, b, c, d):
    """
    Golden model matching your RTL algorithm.

    Equation:
        a*x^3 + b*x^2 + c*x + d = 0

    Output:
        x1_re, x1_im,
        x2_re, x2_im,
        x3_re, x3_im
    """

    # RTL input is FP32, so quantize input first
    a = to_f32(a)
    b = to_f32(b)
    c = to_f32(c)
    d = to_f32(d)

    # Your RTL currently does not explicitly handle a == 0.
    # For golden model, return NaN in this case.
    if a == 0.0:
        nan = to_f32(float("nan"))
        return {
            "x1_re": nan, "x1_im": nan,
            "x2_re": nan, "x2_im": nan,
            "x3_re": nan, "x3_im": nan,
        }

    # Normalize cubic:
    # x^3 + ba*x^2 + ca*x + da = 0
    ba = b / a
    ca = c / a
    da = d / a

    b3a = ba / 3.0

    # Depressed cubic:
    # y^3 + p*y + q = 0
    # x = y - b/(3a)
    p = ca - 3.0 * b3a * b3a
    q = 2.0 * b3a * b3a * b3a - b3a * ca + da

    q2 = q / 2.0
    p3 = p / 3.0

    delta = q2 * q2 + p3 * p3 * p3

    minus_q2 = -q2
    minus_p3 = -p3

    # Case 1:
    # delta >= 0
    # 1 real root and 2 complex roots,
    # or repeated real roots when delta == 0.
    if delta >= 0.0:
        sqrt_delta = math.sqrt(delta)

        u_inner = minus_q2 + sqrt_delta
        v_inner = minus_q2 - sqrt_delta

        u = real_cbrt(u_inner)
        v = real_cbrt(v_inner)

        u_v_add = u + v
        u_v_sub = u - v

        x1_re = u_v_add - b3a
        x1_im = 0.0

        x23_re = -0.5 * u_v_add - b3a
        x23_im = (math.sqrt(3.0) / 2.0) * u_v_sub

        x2_re = x23_re
        x2_im = x23_im

        x3_re = x23_re
        x3_im = -x23_im

    # Case 2:
    # delta < 0
    # 3 distinct real roots.
    else:
        sqrt_minus_p3 = math.sqrt(minus_p3)
        denom = minus_p3 * sqrt_minus_p3

        acos_inner = minus_q2 / denom

        # Avoid small numerical overflow outside [-1, 1]
        if acos_inner > 1.0:
            acos_inner = 1.0
        elif acos_inner < -1.0:
            acos_inner = -1.0

        theta = math.acos(acos_inner)
        theta_3 = theta / 3.0

        angle1 = theta_3 + 2.0 * math.pi / 3.0
        angle2 = theta_3 + 4.0 * math.pi / 3.0

        coef = 2.0 * sqrt_minus_p3

        t1 = coef * math.cos(theta_3)
        t2 = coef * math.cos(angle1)
        t3 = coef * math.cos(angle2)

        x1_re = t1 - b3a
        x2_re = t2 - b3a
        x3_re = t3 - b3a

        x1_im = 0.0
        x2_im = 0.0
        x3_im = 0.0

    return {
        "x1_re": to_f32(x1_re),
        "x1_im": to_f32(x1_im),
        "x2_re": to_f32(x2_re),
        "x2_im": to_f32(x2_im),
        "x3_re": to_f32(x3_re),
        "x3_im": to_f32(x3_im),
    }


def cubic_solver_golden_hex(a, b, c, d):
    r = cubic_solver_golden(a, b, c, d)

    return {
        "x1_re": f32_to_hex(r["x1_re"]),
        "x1_im": f32_to_hex(r["x1_im"]),
        "x2_re": f32_to_hex(r["x2_re"]),
        "x2_im": f32_to_hex(r["x2_im"]),
        "x3_re": f32_to_hex(r["x3_re"]),
        "x3_im": f32_to_hex(r["x3_im"]),
    }


def make_vectors(input_csv="testcases.csv"):
    input_path = resolve_path(input_csv)

    output_path = input_path.with_name(f"vectors_{input_path.stem}.txt")

    output_path.parent.mkdir(parents=True, exist_ok=True)

    with open(input_path, "r", newline="") as f_in, open(output_path, "w", newline="") as f_out:
        reader = csv.DictReader(f_in)

        for row in reader:
            a = float(row["a"])
            b = float(row["b"])
            c = float(row["c"])
            d = float(row["d"])

            out = cubic_solver_golden_hex(a, b, c, d)

            a_hex = f32_to_hex(a)
            b_hex = f32_to_hex(b)
            c_hex = f32_to_hex(c)
            d_hex = f32_to_hex(d)

            f_out.write(
                f"{a_hex} {b_hex} {c_hex} {d_hex} "
                f"{out['x1_re']} {out['x1_im']} "
                f"{out['x2_re']} {out['x2_im']} "
                f"{out['x3_re']} {out['x3_im']}\n"
            )

    print(f"Generated {output_path}")


def make_vectors_for_all_csvs():
    csv_files = sorted(
        path for path in BASE_DIR.glob("*.csv")
        if path.is_file()
    )

    if not csv_files:
        print(f"No CSV testcase files found in {BASE_DIR}")
        return

    for csv_file in csv_files:
        make_vectors(csv_file.name)


def parse_args():
    parser = argparse.ArgumentParser(
        description="Generate FP32 vector files from testcase CSV files."
    )

    group = parser.add_mutually_exclusive_group()
    group.add_argument(
        "-i",
        "--input",
        default="testcases.csv",
        help="CSV testcase file to process. Relative paths are resolved from the script folder.",
    )
    group.add_argument(
        "-a",
        "--all",
        action="store_true",
        help="Process every CSV testcase file in the script folder.",
    )

    return parser.parse_args()


if __name__ == "__main__":
    args = parse_args()

    if args.all:
        make_vectors_for_all_csvs()
    else:
        make_vectors(args.input)