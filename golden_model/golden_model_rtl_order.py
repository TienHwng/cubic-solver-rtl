import math
import struct
import csv
import argparse
from pathlib import Path
import numpy as np


BASE_DIR = Path(__file__).resolve().parent

# RTL constants from cubic_solver.v
FP_2         = 0x40000000
FP_3         = 0x40400000
FP_MINUS_0_5 = 0xBF000000
FP_SQRT3_2   = 0x3F5DB3D7
FP_2PI_3     = 0x40060A92
FP_4PI_3     = 0x40860A92
FP_0         = 0x00000000


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


def fneg(x):
    # Match RTL sign-bit flip style as much as possible
    return bits_to_f32(f32_to_bits(x) ^ 0x80000000)


def fadd(a, b):
    return to_f32(to_f32(a) + to_f32(b))


def fsub(a, b):
    return to_f32(to_f32(a) - to_f32(b))


def fmul(a, b):
    return to_f32(to_f32(a) * to_f32(b))


def fdiv(a, b):
    return to_f32(to_f32(a) / to_f32(b))


def fsqrt(x):
    x = to_f32(x)
    if x < 0.0:
        return to_f32(float("nan"))
    return to_f32(math.sqrt(x))


def real_cbrt(x):
    x = to_f32(x)
    if x >= 0.0:
        return to_f32(abs(x) ** (1.0 / 3.0))
    else:
        return to_f32(-((-x) ** (1.0 / 3.0)))


def facos(x):
    x = to_f32(x)
    # avoid Python domain error; RTL approx may also saturate/approx around edges
    if x > 1.0:
        x = to_f32(1.0)
    elif x < -1.0:
        x = to_f32(-1.0)
    return to_f32(math.acos(x))


def fcos(x):
    return to_f32(math.cos(to_f32(x)))


def cubic_solver_golden(a, b, c, d):
    """
    RTL-order golden model for cubic_solver.v.

    This tries to match the output order of the RTL FSM:

    delta >= 0 branch:
        x1 = u + v - b3a
        x2 = -0.5*(u+v) - b3a + j*(sqrt(3)/2)*(u-v)
        x3 = -0.5*(u+v) - b3a - j*(sqrt(3)/2)*(u-v)

    delta < 0 branch:
        x1 = 2*sqrt(-p/3)*cos(theta/3)          - b3a
        x2 = 2*sqrt(-p/3)*cos(theta/3 + 2pi/3)  - b3a
        x3 = 2*sqrt(-p/3)*cos(theta/3 + 4pi/3)  - b3a
    """

    # RTL input is FP32
    a = to_f32(a)
    b = to_f32(b)
    c = to_f32(c)
    d = to_f32(d)

    if a == 0.0:
        nan = to_f32(float("nan"))
        return {
            "x1_re": nan, "x1_im": nan,
            "x2_re": nan, "x2_im": nan,
            "x3_re": nan, "x3_im": nan,
        }

    # Match the state-by-state arithmetic more closely by quantizing to FP32
    # after every operation.
    ba = fdiv(b, a)
    ca = fdiv(c, a)
    da = fdiv(d, a)

    b3a = fdiv(ba, bits_to_f32(FP_3))

    b3a_sq = fmul(b3a, b3a)
    term_q2 = fmul(b3a, ca)
    term_p2 = fmul(bits_to_f32(FP_3), b3a_sq)
    b3a_cb = fmul(b3a_sq, b3a)
    term_q1 = fmul(bits_to_f32(FP_2), b3a_cb)

    p = fsub(ca, term_p2)
    q_tmp = fsub(term_q1, term_q2)
    q = fadd(q_tmp, da)

    q2 = fdiv(q, bits_to_f32(FP_2))
    p3 = fdiv(p, bits_to_f32(FP_3))

    q2_sq = fmul(q2, q2)
    p3_sq = fmul(p3, p3)
    p3_cb = fmul(p3_sq, p3)
    delta = fadd(q2_sq, p3_cb)

    minus_q2 = fneg(q2)
    minus_p3 = fneg(p3)

    # RTL decides by sign bit of delta:
    # if delta[31] == 1 -> V branch
    # else              -> C branch
    delta_negative = ((f32_to_bits(delta) >> 31) & 1) == 1

    if not delta_negative:
        # C branch: delta >= 0
        sqrt_delta = fsqrt(delta)

        u_inner = fadd(minus_q2, sqrt_delta)
        v_inner = fsub(minus_q2, sqrt_delta)

        u = real_cbrt(u_inner)
        v = real_cbrt(v_inner)

        u_v_add = fadd(u, v)
        u_v_sub = fsub(u, v)

        x1_re = fsub(u_v_add, b3a)
        x1_im = bits_to_f32(FP_0)

        t23_re = fmul(bits_to_f32(FP_MINUS_0_5), u_v_add)
        t23_im_mag = fmul(bits_to_f32(FP_SQRT3_2), u_v_sub)

        x23_re = fsub(t23_re, b3a)

        x2_re = x23_re
        x2_im = t23_im_mag

        x3_re = x23_re
        x3_im = fneg(t23_im_mag)

    else:
        # V branch: delta < 0
        sqrt_minus_p3 = fsqrt(minus_p3)
        denom = fmul(minus_p3, sqrt_minus_p3)

        acos_inner = fdiv(minus_q2, denom)
        theta = facos(acos_inner)
        theta_3 = fdiv(theta, bits_to_f32(FP_3))

        angle1 = fadd(theta_3, bits_to_f32(FP_2PI_3))
        angle2 = fadd(theta_3, bits_to_f32(FP_4PI_3))

        cos0 = fcos(theta_3)
        cos1 = fcos(angle1)
        cos2 = fcos(angle2)

        coef = fmul(bits_to_f32(FP_2), sqrt_minus_p3)

        t1 = fmul(coef, cos0)
        t2 = fmul(coef, cos1)
        t3 = fmul(coef, cos2)

        x1_re = fsub(t1, b3a)
        x2_re = fsub(t2, b3a)
        x3_re = fsub(t3, b3a)

        x1_im = bits_to_f32(FP_0)
        x2_im = bits_to_f32(FP_0)
        x3_im = bits_to_f32(FP_0)

    return {
        "x1_re": to_f32(x1_re), "x1_im": to_f32(x1_im),
        "x2_re": to_f32(x2_re), "x2_im": to_f32(x2_im),
        "x3_re": to_f32(x3_re), "x3_im": to_f32(x3_im),
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


def make_vectors(input_csv="testcases.csv", output_name="vectors.txt"):
    input_path = resolve_path(input_csv)
    output_path = resolve_path(output_name)

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


def parse_args():
    parser = argparse.ArgumentParser(description="Generate RTL-order FP32 vectors for cubic_solver.v")
    parser.add_argument("-i", "--input", default="testcases.csv", help="Input CSV file")
    parser.add_argument("-o", "--output", default="vectors.txt", help="Output vector file")
    return parser.parse_args()


if __name__ == "__main__":
    args = parse_args()
    make_vectors(args.input, args.output)
