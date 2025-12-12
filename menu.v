module menu (
    input clk,
    input rst,
    input btn_left,    
    input btn_right,   
    input sw_mode,     
    
    output reg [3:0] cursor_mode, 
    output reg is_running         
);

    parameter WATCH     = 4'd0;
    parameter STOPWATCH = 4'd1;
    parameter TIMER     = 4'd2;
    parameter SETTING   = 4'd3;
    parameter WORLD     = 4'd4;
    parameter ALARM     = 4'd5;
    parameter DATE      = 4'd6;
    parameter SOUND_ALM = 4'd7;
    parameter METRONOME = 4'd8;
    parameter DDAY      = 4'd9;
    parameter REACTION  = 4'd10; 
    parameter MUSIC     = 4'd11;
    parameter LAB_REC   = 4'd12;
    parameter PIANO     = 4'd13; 
    
    reg btn_left_prev, btn_right_prev;
    wire left_clicked, right_clicked;

    always @(posedge clk) begin
        if (rst) begin
            btn_left_prev <= 0; btn_right_prev <= 0;
        end else begin
            btn_left_prev <= btn_left; 
            btn_right_prev <= btn_right;
        end
    end

    assign left_clicked   = (btn_left == 1) && (btn_left_prev == 0);
    assign right_clicked  = (btn_right == 1) && (btn_right_prev == 0);

    always @(posedge clk) begin
        if (rst) begin
            cursor_mode <= WATCH;
            is_running  <= 0;
        end else begin
            is_running <= sw_mode;

            if (sw_mode == 0) begin
                // === 오른쪽 버튼 (다음 메뉴) ===
                if (right_clicked) begin
                    // 마지막(PIANO)에서 누르면 처음(WATCH)으로
                    if (cursor_mode == PIANO) cursor_mode <= WATCH;
                    else cursor_mode <= cursor_mode + 1;
                end
                // === 왼쪽 버튼 (이전 메뉴) ===
                else if (left_clicked) begin
                    // 처음(WATCH)에서 누르면 마지막(PIANO)으로
                    if (cursor_mode == WATCH) cursor_mode <= PIANO;
                    else cursor_mode <= cursor_mode - 1;
                end
            end
        end
    end

endmodule