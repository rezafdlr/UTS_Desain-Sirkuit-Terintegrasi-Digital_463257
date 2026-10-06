module top_tm1638_demo (
    input wire clk,         // Master clock iCESugar (12 MHz)
    output reg tm_cs,
    output tm_clk,          // Clock ke TM1638
    inout  tm_dio
    );

    localparam 
        HIGH    = 1'b1,
        LOW     = 1'b0;

    // Definisi parameter karakter 7-segment display
    localparam [6:0]
        S_0     = 7'b0111111,
        S_1     = 7'b0000110,
        S_2     = 7'b1011011,
        S_3     = 7'b1001111,
        S_4     = 7'b1100110,
        S_5     = 7'b1101101,
        S_6     = 7'b1111101,
        S_7     = 7'b0000111,
        S_8     = 7'b1111111,
        S_9     = 7'b1101111,
        S_BLK   = 7'b0000000,
        S_t     = 7'b1111000,
        S_e     = 7'b1111011,
        S_DASH  = 7'b1000000;

    localparam [7:0]
        C_READ  = 8'b01000010,
        C_WRITE = 8'b01000000,
        C_DISP  = 8'b10001111,
        C_ADDR  = 8'b11000000;

    //localparam CLK_DIV = 22; 

    // 34 data array teks NIM dengan padding awal dan akhir yang akan ditampilkan dalam frame 8 digit 7 segment display
    reg [6:0] text_array [0:33];
    
    initial begin
        // Padding Kosong Awal (8 digit)
        text_array[0]=S_BLK; text_array[1]=S_BLK; text_array[2]=S_BLK; text_array[3]=S_BLK;
        text_array[4]=S_BLK; text_array[5]=S_BLK; text_array[6]=S_BLK; text_array[7]=S_BLK;
        
        // NIM : "20-463257-te-51249"
        text_array[8] =S_2;    text_array[9] =S_0;    text_array[10]=S_DASH; text_array[11]=S_4;
        text_array[12]=S_6;    text_array[13]=S_3;    text_array[14]=S_2;    text_array[15]=S_5;
        text_array[16]=S_7;    text_array[17]=S_DASH; text_array[18]=S_t;    text_array[19]=S_e;
        text_array[20]=S_DASH; text_array[21]=S_5;    text_array[22]=S_1;    text_array[23]=S_2;
        text_array[24]=S_4;    text_array[25]=S_9;
        
        // Padding Kosong Akhir (8 digit)
        text_array[26]=S_BLK; text_array[27]=S_BLK; text_array[28]=S_BLK; text_array[29]=S_BLK;
        text_array[30]=S_BLK; text_array[31]=S_BLK; text_array[32]=S_BLK; text_array[33]=S_BLK;
    end


    reg rst = HIGH;

    reg [5:0] instruction_step;
    reg [7:0] keys = 8'b0;                     // Menyimpan status tombol S1 - S8

    reg [7:0] larson;
    reg larson_dir;
    //reg [CLK_DIV:0] counter=0;
    reg counter = 0;

    parameter TICK_MAX = 24'd11_999_999; 
    reg [23:0] sec_cnt = 0;
    wire tick_div = (sec_cnt == TICK_MAX);

    always @(posedge clk) begin
        sec_cnt <= tick_div ? 24'd0 : sec_cnt + 1'b1;
    end

    // set up tristate IO pin for display
    //   tm_dio     is physical pin
    //   dio_in     for reading from display
    //   dio_out    for sending to display
    //   tm_rw      selects input or output
    reg tm_rw;
    wire dio_in, dio_out;
    SB_IO #(
        .PIN_TYPE(6'b101001),
        .PULLUP(1'b1)
    ) tm_dio_io (
        .PACKAGE_PIN(tm_dio),
        .OUTPUT_ENABLE(tm_rw),
        .D_IN_0(dio_in),
        .D_OUT_0(dio_out)
    );

    // setup tm1638 module with it's tristate IO
    //   tm_in      is read from module
    //   tm_out     is written to module
    //   tm_latch   triggers the module to read/write display
    //   tm_rw      selects read or write mode to display
    //   busy       indicates when module is busy
    //                (another latch will interrupt)
    //   tm_clk     is the data clk
    //   dio_in     for reading from display
    //   dio_out    for sending to display
    //
    //   tm_data    the tristate io pin to module
    wire busy;
    wire [7:0] tm_data, tm_in;
    reg [7:0] tm_out;
    reg tm_latch;
   

    assign tm_in = tm_data;
    assign tm_data = tm_rw ? tm_out : 8'hZZ;

    tm1638 u_tm1638 (
        .clk(clk),
        .rst(rst),
        .data_latch(tm_latch),
        .data(tm_data),
        .rw(tm_rw),
        .busy(busy),
        .sclk(tm_clk),
        .dio_in(dio_in),
        .dio_out(dio_out)
    );

    // Pemilihan mode (latched, sekali tekan)
    reg [1:0] sw     = 2'b00;   // 01 = kiri, 10 = kanan, 00 = ping-pong
    reg       active = 1'b0;    // 0 = belum ada tombol ditekan -> teks diam
    reg [7:0] keys_prev = 8'b0;
    wire [7:0] key_press = keys & ~keys_prev;   // tepi naik = baru ditekan

    always @(posedge clk) begin
        keys_prev <= keys;
        if (rst) begin
            sw     <= 2'b00;
            active <= 1'b0;
        end else if (key_press[7]) begin        // S1
            sw <= 2'b01;  active <= 1'b1;
        end else if (key_press[6]) begin        // S2
            sw <= 2'b10;  active <= 1'b1;
        end else if (key_press[5]) begin        // S3
            sw <= 2'b00;  active <= 1'b1;
        end
    end

    // Sliding window
    reg [4:0] offset    = 5'd8;  // awal: NIM terlihat diam di layar
    reg [4:0] frame     = 0;
    reg       direction = 0;     // 0 = kiri, 1 = kanan (dipakai ping-pong)

    always @(posedge clk) begin
        if (rst) begin
            offset    <= 5'd8;
            direction <= 1'b0;
        end else if (tick_div && active) begin
            case (sw)
                2'b01: begin                                // kiri terus
                    direction <= 1'b0;
                    offset <= (offset < 26) ? offset + 1'b1 : 5'd1;
                end
                2'b10: begin                                // kanan terus
                    direction <= 1'b1;
                    offset <= (offset > 0) ? offset - 1'b1 : 5'd25;
                end
                default: begin                              // 2'b00 ping-pong
                    if (!direction) begin
                        if (offset < 26) offset <= offset + 1'b1;
                        else begin direction <= 1'b1; offset <= offset - 1'b1; end
                    end else begin
                        if (offset > 0) offset <= offset - 1'b1;
                        else begin direction <= 1'b0; offset <= offset + 1'b1; end
                    end
                end
            endcase
        end
    end





    // handles displaying 1-8 on a display location
    // and animating the decimal point
    task display_digit;
        input [2:0] key;
        input [6:0] segs;

        begin
            tm_latch <= HIGH;
            tm_out <= {1'b0, segs};
        end
    endtask

    // handles animating the LEDs 1-8
    task display_led;
        input [2:0] dot;

        begin
            tm_latch <= HIGH;
            tm_out <= {7'b0, larson[dot]};
            //tm_out <= {7'b0, leds[dot]};
        end
    endtask

    always @(posedge clk) begin
        if (rst) begin
            instruction_step <= 6'b0;
            tm_cs <= HIGH;
            tm_rw <= HIGH;
            rst <= LOW;
            tm_latch <= LOW;
            counter <= 0;
            keys <= 8'b0;
            larson_dir <= 0;
            larson <= 8'b00010000;

        end else begin
            if (tick_div) begin
                larson_dir <= larson[6] ? 0 : larson[1] ? 1 : larson_dir;

                if (larson_dir)
                    larson <= {larson[6:0], larson[7]};
                else
                    larson <= {larson[0], larson[7:1]};
            end

            if (counter[0] && ~busy) begin
                case (instruction_step)
                    // *** KEYS ***
                    1:  {tm_cs, tm_rw}     <= {LOW, HIGH};
                    2:  {tm_latch, tm_out} <= {HIGH, C_READ}; // read mode
                    3:  {tm_latch, tm_rw}  <= {HIGH, LOW};

                    //  read back keys S1 - S8
                    4:  {keys[7], keys[3]} <= {tm_in[0], tm_in[4]};
                    5:  {tm_latch}         <= {HIGH};
                    6:  {keys[6], keys[2]} <= {tm_in[0], tm_in[4]};
                    7:  {tm_latch}         <= {HIGH};
                    8:  {keys[5], keys[1]} <= {tm_in[0], tm_in[4]};
                    9:  {tm_latch}         <= {HIGH};
                    10: {keys[4], keys[0]} <= {tm_in[0], tm_in[4]};
                    11: {tm_cs}            <= {HIGH};

                    // *** DISPLAY ***
                    12: {tm_cs, tm_rw}     <= {LOW, HIGH};
                    13: {tm_latch, tm_out} <= {HIGH, C_WRITE}; // write mode
                    14: {tm_cs}            <= {HIGH};

                    15: {tm_cs, tm_rw}     <= {LOW, HIGH};
                    16: begin 
                            {tm_latch, tm_out} <= {HIGH, C_ADDR}; 
                            frame <= offset; 
                        end
                    //Window Frame Running Text NIM
                    // Menampilkan 8 digit dari array teks sesuai offset geseran
                    
                    //frame untuk menunjukan yang ditampilkan di 8 digit 7segment

                    17: display_digit(3'd7, text_array[frame]);     // Digit 1
                    18: display_led(3'd0);                       // LED 1
                    19: display_digit(3'd6, text_array[frame+1]);   // Digit 2
                    20: display_led(3'd1);                       // LED 2
                    21: display_digit(3'd5, text_array[frame+2]);   // Digit 3
                    22: display_led(3'd2);                       // LED 3
                    23: display_digit(3'd4, text_array[frame+3]);   // Digit 4
                    24: display_led(3'd3);                       // LED 4
                    25: display_digit(3'd3, text_array[frame+4]);   // Digit 5
                    26: display_led(3'd4);                       // LED 5
                    27: display_digit(3'd2, text_array[frame+5]);   // Digit 6
                    28: display_led(3'd5);                       // LED 6
                    29: display_digit(3'd1, text_array[frame+6]);   // Digit 7
                    30: display_led(3'd6);                       // LED 7
                    31: display_digit(3'd0, text_array[frame+7]);   // Digit 8
                    32: display_led(3'd7);                       // LED 8


                    33: {tm_cs}            <= {HIGH};

                    34: {tm_cs, tm_rw}     <= {LOW, HIGH};
                    35: {tm_latch, tm_out} <= {HIGH, C_DISP}; // display on, full bright
                    36: {tm_cs}            <= {HIGH};

                endcase

                if (instruction_step >= 44) 
                    instruction_step <= 0;
                else 
                instruction_step <= instruction_step + 1;
                

            end else if (busy) begin
                // pull latch low next clock cycle after module has been
                // latched
                tm_latch <= LOW;
            end

            counter <= counter + 1;
        end
    end
endmodule