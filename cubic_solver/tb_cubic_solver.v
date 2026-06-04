`timescale 1ns/1ps

module tb_cubic_solver;

    // ============================================================
    // Config
    // ============================================================
    parameter VECTOR_FILE    = "vectors.txt";
    parameter TIMEOUT_CYCLES = 200;

    // Tolerance:
    // pass if abs(DUT - EXP) <= max(ABS_TOL, REL_TOL * abs(EXP))
    real ABS_TOL;
    real REL_TOL;

    // ============================================================
    // DUT signals - pure Verilog: reg/wire only
    // ============================================================
    reg         clk;
    reg         rst_n;
    reg         start;

    reg  [31:0] a;
    reg  [31:0] b;
    reg  [31:0] c;
    reg  [31:0] d;

    wire        done;

    wire [31:0] x1_re;
    wire [31:0] x1_im;
    wire [31:0] x2_re;
    wire [31:0] x2_im;
    wire [31:0] x3_re;
    wire [31:0] x3_im;

    // Expected values from vectors.txt
    reg [31:0] exp_x1_re;
    reg [31:0] exp_x1_im;
    reg [31:0] exp_x2_re;
    reg [31:0] exp_x2_im;
    reg [31:0] exp_x3_re;
    reg [31:0] exp_x3_im;

    integer fd;
    integer status;
    integer test_id;
    integer pass_count;
    integer fail_count;
    integer skip_count;

    // Vector variables
    reg [31:0] vec_a;
    reg [31:0] vec_b;
    reg [31:0] vec_c;
    reg [31:0] vec_d;

    reg [31:0] vec_x1_re;
    reg [31:0] vec_x1_im;
    reg [31:0] vec_x2_re;
    reg [31:0] vec_x2_im;
    reg [31:0] vec_x3_re;
    reg [31:0] vec_x3_im;

    // ============================================================
    // DUT instance
    // ============================================================
    cubic_solver dut (
        .clk   (clk),
        .rst_n (rst_n),
        .start (start),
        .a     (a),
        .b     (b),
        .c     (c),
        .d     (d),

        .done  (done),

        .x1_re (x1_re),
        .x1_im (x1_im),
        .x2_re (x2_re),
        .x2_im (x2_im),
        .x3_re (x3_re),
        .x3_im (x3_im)
    );

    // ============================================================
    // Clock generation
    // ============================================================
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // ============================================================
    // Helper functions - pure Verilog compatible
    // ============================================================

    function integer is_nan;
        input [31:0] fp;
        begin
            is_nan = (fp[30:23] == 8'hFF) && (fp[22:0] != 0);
        end
    endfunction

    function real abs_real;
        input real v;
        begin
            if (v < 0.0)
                abs_real = -v;
            else
                abs_real = v;
        end
    endfunction

    function real pow2_int;
        input integer exp;
        integer i;
        real result;
        begin
            result = 1.0;

            if (exp > 0) begin
                for (i = 0; i < exp; i = i + 1)
                    result = result * 2.0;
            end
            else if (exp < 0) begin
                for (i = 0; i < -exp; i = i + 1)
                    result = result / 2.0;
            end

            pow2_int = result;
        end
    endfunction

    function real fp32_to_real;
        input [31:0] fp;

        integer sign;
        integer exp_raw;
        integer exp_unbiased;
        integer mant_raw;
        real mant;
        real value;
        begin
            sign     = fp[31];
            exp_raw  = fp[30:23];
            mant_raw = fp[22:0];

            // NaN / Inf: return a very large number.
            // Real NaN is not portable in pure Verilog.
            if (exp_raw == 255) begin
                value = 1.0e30;
            end

            // Zero / subnormal
            else if (exp_raw == 0) begin
                if (mant_raw == 0) begin
                    value = 0.0;
                end
                else begin
                    mant  = mant_raw / 8388608.0; // 2^23
                    value = mant * pow2_int(-126);
                end
            end

            // Normal number
            else begin
                exp_unbiased = exp_raw - 127;
                mant  = 1.0 + (mant_raw / 8388608.0); // 1 + mantissa / 2^23
                value = mant * pow2_int(exp_unbiased);
            end

            if (sign)
                fp32_to_real = -value;
            else
                fp32_to_real = value;
        end
    endfunction

    function integer fp32_close;
        input [31:0] dut_value;
        input [31:0] exp_value;

        real dut_real;
        real exp_real;
        real diff;
        real tol;
        begin
            // Exact same bit pattern is always accepted
            if (dut_value === exp_value) begin
                fp32_close = 1;
            end

            // NaN handling
            else if (is_nan(dut_value) && is_nan(exp_value)) begin
                fp32_close = 1;
            end
            else if (is_nan(dut_value) || is_nan(exp_value)) begin
                fp32_close = 0;
            end

            // Numeric comparison with tolerance
            else begin
                dut_real = fp32_to_real(dut_value);
                exp_real = fp32_to_real(exp_value);

                diff = abs_real(dut_real - exp_real);
                tol  = ABS_TOL;

                if ((REL_TOL * abs_real(exp_real)) > tol)
                    tol = REL_TOL * abs_real(exp_real);

                if (diff <= tol)
                    fp32_close = 1;
                else
                    fp32_close = 0;
            end
        end
    endfunction

    // ============================================================
    // Print helpers
    // ============================================================

    task print_one_signal;
        input [8*8-1:0] name;
        input [31:0]    dut_value;
        input [31:0]    exp_value;
        begin
            $display("  %s | DUT = %h (%f) | EXP = %h (%f) | %s",
                name,
                dut_value, fp32_to_real(dut_value),
                exp_value, fp32_to_real(exp_value),
                fp32_close(dut_value, exp_value) ? "OK" : "MISMATCH"
            );
        end
    endtask

    // ============================================================
    // Run one testcase
    // ============================================================

    task run_one_test;
        input [31:0] in_a;
        input [31:0] in_b;
        input [31:0] in_c;
        input [31:0] in_d;

        input [31:0] in_x1_re;
        input [31:0] in_x1_im;
        input [31:0] in_x2_re;
        input [31:0] in_x2_im;
        input [31:0] in_x3_re;
        input [31:0] in_x3_im;

        integer timeout_count;
        integer pass;
        begin
            // Apply input
            a = in_a;
            b = in_b;
            c = in_c;
            d = in_d;

            exp_x1_re = in_x1_re;
            exp_x1_im = in_x1_im;
            exp_x2_re = in_x2_re;
            exp_x2_im = in_x2_im;
            exp_x3_re = in_x3_re;
            exp_x3_im = in_x3_im;

            // Pulse start for 1 clock cycle
            @(posedge clk);
            start = 1'b1;

            @(posedge clk);
            start = 1'b0;

            // Wait done with timeout
            timeout_count = 0;

            while ((done !== 1'b1) && (timeout_count < TIMEOUT_CYCLES)) begin
                @(posedge clk);
                timeout_count = timeout_count + 1;
            end

            if (timeout_count >= TIMEOUT_CYCLES) begin
                $display("[TIMEOUT] Test %0d", test_id);
                $display("Input:");
                $display("  a = %h (%f)", a, fp32_to_real(a));
                $display("  b = %h (%f)", b, fp32_to_real(b));
                $display("  c = %h (%f)", c, fp32_to_real(c));
                $display("  d = %h (%f)", d, fp32_to_real(d));

                fail_count = fail_count + 1;
                test_id = test_id + 1;
            end
            else begin
                // Wait one more cycle so outputs are stable in log/waveform
                @(posedge clk);

                pass =
                    fp32_close(x1_re, exp_x1_re) &&
                    fp32_close(x1_im, exp_x1_im) &&
                    fp32_close(x2_re, exp_x2_re) &&
                    fp32_close(x2_im, exp_x2_im) &&
                    fp32_close(x3_re, exp_x3_re) &&
                    fp32_close(x3_im, exp_x3_im);

                if (pass) begin
                    $display("[PASS] Test %0d", test_id);
                    pass_count = pass_count + 1;
                end
                else begin
                    $display("[FAIL] Test %0d", test_id);

                    $display("Input:");
                    $display("  a = %h (%f)", a, fp32_to_real(a));
                    $display("  b = %h (%f)", b, fp32_to_real(b));
                    $display("  c = %h (%f)", c, fp32_to_real(c));
                    $display("  d = %h (%f)", d, fp32_to_real(d));

                    $display("Compare:");
                    print_one_signal("x1_re", x1_re, exp_x1_re);
                    print_one_signal("x1_im", x1_im, exp_x1_im);
                    print_one_signal("x2_re", x2_re, exp_x2_re);
                    print_one_signal("x2_im", x2_im, exp_x2_im);
                    print_one_signal("x3_re", x3_re, exp_x3_re);
                    print_one_signal("x3_im", x3_im, exp_x3_im);

                    fail_count = fail_count + 1;
                end

                test_id = test_id + 1;
            end
        end
    endtask

    // ============================================================
    // Main test sequence
    // ============================================================

    initial begin
        ABS_TOL = 0.01;
        REL_TOL = 0.01;

        rst_n = 1'b0;
        start = 1'b0;

        a = 32'h00000000;
        b = 32'h00000000;
        c = 32'h00000000;
        d = 32'h00000000;

        test_id    = 0;
        pass_count = 0;
        fail_count = 0;
        skip_count = 0;

        // Optional waveform dump
        `ifdef DUMP_WAVE
            $dumpfile("tb_cubic_solver.vcd");
            $dumpvars(0, tb_cubic_solver);
        `endif

        // Reset sequence
        repeat (5) @(posedge clk);
        rst_n = 1'b1;
        repeat (2) @(posedge clk);

        // Open vector file
        fd = $fopen(VECTOR_FILE, "r");

        if (fd == 0) begin
            $display("ERROR: Cannot open vector file: %s", VECTOR_FILE);
            $display("Make sure vectors.txt is in the simulator working directory.");
            $finish;
        end

        $display("============================================================");
        $display("Start cubic_solver simulation");
        $display("Vector file: %s", VECTOR_FILE);
        $display("ABS_TOL = %f, REL_TOL = %f", ABS_TOL, REL_TOL);
        $display("Expected format per line:");
        $display("a b c d x1_re x1_im x2_re x2_im x3_re x3_im");
        $display("============================================================");

        // Read vectors.txt
        //
        // Expected format:
        // 10 hex values per line:
        // a b c d x1_re x1_im x2_re x2_im x3_re x3_im
        //
        // Example:
        // 3F800000 C0C00000 41300000 C0C00000 40400000 00000000 3F800000 00000000 40000000 00000000
        while (!$feof(fd)) begin
            status = $fscanf(
                fd,
                "%h %h %h %h %h %h %h %h %h %h\n",
                vec_a,
                vec_b,
                vec_c,
                vec_d,
                vec_x1_re,
                vec_x1_im,
                vec_x2_re,
                vec_x2_im,
                vec_x3_re,
                vec_x3_im
            );

            if (status == 10) begin
                run_one_test(
                    vec_a,
                    vec_b,
                    vec_c,
                    vec_d,
                    vec_x1_re,
                    vec_x1_im,
                    vec_x2_re,
                    vec_x2_im,
                    vec_x3_re,
                    vec_x3_im
                );
            end
            else begin
                skip_count = skip_count + 1;
            end
        end

        $fclose(fd);

        $display("============================================================");
        $display("Simulation finished");
        $display("PASS = %0d", pass_count);
        $display("FAIL = %0d", fail_count);
        $display("SKIP = %0d", skip_count);
        $display("TOTAL TESTED = %0d", pass_count + fail_count);
        $display("============================================================");

        if (fail_count == 0)
            $display("RESULT: ALL TESTS PASSED");
        else
            $display("RESULT: SOME TESTS FAILED");

        $finish;
    end

endmodule
