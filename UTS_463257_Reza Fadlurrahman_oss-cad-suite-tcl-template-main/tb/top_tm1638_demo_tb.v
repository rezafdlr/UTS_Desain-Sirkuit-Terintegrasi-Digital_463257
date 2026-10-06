`timescale 1ns/1ps

module top_tm1638_demo_tb;
    reg clk;
    wire tm_cs;
    wire tm_clk;
    wire tm_dio;

    pullup(tm_dio);

    // Panggil Modul Utama
    top_tm1638_demo uut (
        .clk(clk),
        .tm_cs(tm_cs),
        .tm_clk(tm_clk),
        .tm_dio(tm_dio)
    );

    // Percepat waktu
    defparam uut.TICK_MAX = 24'd50;

    initial begin
        clk = 0;
        forever #41.67 clk = ~clk; // Clock 12MHz iCESugar
    end

    initial begin
        $dumpfile("build/top_tm1638_demo_tb.vcd");
        $dumpvars(0, top_tm1638_demo_tb);
        
        // Memunculkan sinyal internal pergeseran teks ke GTKWave
        $dumpvars(1, uut.offset);
        $dumpvars(1, uut.direction);
        $dumpvars(1, uut.keys);

        // SKENARIO 1: Tidak ada tombol TM1638 yang ditekan (Tes Ping-Pong)
        force uut.keys = 8'h00; 
        #500000; 

        // SKENARIO 2: Tombol S1 TM1638 ditekan (Tes Geser Kiri)
        force uut.keys = 8'h80; 
        #300000;

        // SKENARIO 3: Tombol S2 TM1638 ditekan (Tes Geser Kanan)
        force uut.keys = 8'h40; 
        #300000;

        $finish;
    end
endmodule