module textlcd(
    input rst, 
    input clk,
    // 밖에서 받아올 글자 데이터 (1줄당 16글자 * 8비트 = 128비트)
    input [127:0] line1_in, 
    input [127:0] line2_in,
    output lcd_e, lcd_rs, lcd_rw,
    output reg [7:0] lcd_data
);

    wire lcd_e;
    reg lcd_rs, lcd_rw;
    
    reg [2:0] state;
    // 상태 정의
    parameter delay = 0, function_set = 1, entry_mode = 2, disp_onoff = 3, 
              line1 = 4, line2 = 5;

    integer cnt;
    integer cnt_100hz;
    reg clk_100hz;

    // 1. 타이밍용 클럭 생성 (유지 - LCD 구동 필수)
    always @(posedge rst or posedge clk) begin
        if (rst) begin
            cnt_100hz = 0;
            clk_100hz = 0;
        end else if (cnt_100hz >=4 ) begin // 100Hz (10ms)
            cnt_100hz = 0;
            clk_100hz = ~clk_100hz;
        end else begin
            cnt_100hz = cnt_100hz + 1;
        end
    end

    always @(posedge rst or posedge clk_100hz) begin
        if (rst) begin
            state = delay;
            cnt = 0;
        end else begin
            cnt = cnt + 1;
            case (state)
                delay       : if (cnt == 10)  begin state = function_set; cnt = 0; end
                function_set: if (cnt == 5)   begin state = disp_onoff;   cnt = 0; end
                disp_onoff  : if (cnt == 2)   begin state = entry_mode;   cnt = 0; end
                entry_mode  : if (cnt == 2)   begin state = line1;        cnt = 0; end
                
                // Line 1을 다 쓰면 Line 2로
                line1       : if (cnt == 17)  begin state = line2;        cnt = 0; end 
                
                // Line 2를 다 쓰면 다시 Line 1으로 (Clear 안 함!)
                line2       : if (cnt == 17)  begin state = line1;        cnt = 0; end
                
                default     : begin state = delay; cnt = 0; end
            endcase
        end
    end

    // 3. 데이터 출력 로직
    always @(posedge rst or posedge clk_100hz) begin
        if (rst) begin
            lcd_rs = 1; lcd_rw = 1; lcd_data = 0;
        end else begin
            lcd_rw = 0; // 쓰기 모드 고정
            case (state)
                function_set: begin lcd_rs=0; lcd_data = 8'b00111000; end // 8bit, 2line
                disp_onoff  : begin lcd_rs=0; lcd_data = 8'b00001100; end // 화면 켜기
                entry_mode  : begin lcd_rs=0; lcd_data = 8'b00000110; end // 커서 이동

                // [첫 번째 줄 출력]
                line1: begin
                    if (cnt == 0) begin
                        lcd_rs = 0; lcd_data = 8'b10000000; // 커서 홈으로 (0x80)
                    end else begin
                        lcd_rs = 1;
                        // 128비트 입력을 8비트씩 잘라서 출력
                        // cnt 1 -> 첫 글자(가장 높은 비트), cnt 16 -> 마지막 글자
                        lcd_data = line1_in[ (16-cnt)*8 +: 8 ]; 
                    end
                end

                // [두 번째 줄 출력]
                line2: begin
                    if (cnt == 0) begin
                        lcd_rs = 0; lcd_data = 8'b11000000; // 커서 2행으로 (0xC0)
                    end else begin
                        lcd_rs = 1;
                        lcd_data = line2_in[ (16-cnt)*8 +: 8 ];
                    end
                end
            endcase
        end
    end

    assign lcd_e = clk_100hz; // 타이밍 신호

endmodule