module metronome(
    input clk,              // 시스템 클럭 (1kHz)
    input rst,
    input [9:0] sw_num,     // BPM 설정용 스위치 (1:60, 2:90, 3:120 BPM)
    
    output reg servo_pwm,   // 서보 모터 제어 신호 (AA22 핀 연결 예정)
    output [7:0] seg_data,  // 7-세그먼트 데이터
    output [7:0] seg_com    // 7-세그먼트 자리 선택
);

    // -----------------------------------------------------
    // 1. BPM 설정 및 주기 계산
    // -----------------------------------------------------
    reg [9:0] beat_limit; // 틱-톡 간격 (ms 단위)
    reg [9:0] display_num; // 디스플레이에 표시할 숫자

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            beat_limit <= 0; // 0이면 정지
            display_num <= 0;
        end else begin
            // 스위치 입력에 따른 BPM 설정 (우선순위: 높은 번호)
            if (sw_num[3]) begin
                beat_limit <= 333;   // 180 BPM
                display_num <= 180;
            end else if (sw_num[2]) begin
                beat_limit <= 500;   // 120 BPM
                display_num <= 120;
            end else if (sw_num[1]) begin
                beat_limit <= 666;   // 90 BPM
                display_num <= 90;
            end else if (sw_num[0]) begin
                beat_limit <= 1000;  // 60 BPM
                display_num <= 60;
            end else begin
                beat_limit <= 0;     // 스위치 안 누르면 정지
                display_num <= 0;
            end
        end
    end

    // -----------------------------------------------------
    // 2. 메트로놈 타이밍 (Beat Generator)
    // -----------------------------------------------------
    reg [9:0] time_cnt;
    reg direction; // 0: 왼쪽, 1: 오른쪽

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            time_cnt <= 0;
            direction <= 0;
        end else if (beat_limit > 0) begin
            if (time_cnt >= beat_limit) begin
                time_cnt <= 0;
                direction <= ~direction; // 방향 전환 (틱 <-> 톡)
            end else begin
                time_cnt <= time_cnt + 1;
            end
        end else begin
            time_cnt <= 0;
            direction <= 0; // 정지 시 초기 위치
        end
    end

    // -----------------------------------------------------
    // 3. 서보 모터 PWM 생성 (50Hz 주기, 20ms)
    // -----------------------------------------------------
    reg [4:0] pwm_cnt; // 0~19 (20ms 주기 카운터)

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            pwm_cnt <= 0;
            servo_pwm <= 0;
        end else begin
            // 20ms 주기 카운트 (1kHz 클럭이므로 0~19)
            if (pwm_cnt >= 19) pwm_cnt <= 0;
            else pwm_cnt <= pwm_cnt + 1;

            // PWM 펄스 폭 결정
            // direction 0 (왼쪽): 1ms High (pwm_cnt < 1)
            // direction 1 (오른쪽): 2ms High (pwm_cnt < 2)
            if (direction == 0) begin
                servo_pwm <= (pwm_cnt < 1) ? 1 : 0; 
            end else begin
                servo_pwm <= (pwm_cnt < 2) ? 1 : 0;
            end
        end
    end

    // -----------------------------------------------------
    // 4. 디스플레이 출력 (BPM 표시)
    // -----------------------------------------------------
    // "bPn  60" 처럼 표시하거나 숫자만 표시
    wire [7:0] dec_hundred, dec_ten, dec_one;
    
    // 자리수 분리
    wire [3:0] b_hundred = display_num / 100;
    wire [3:0] b_ten     = (display_num % 100) / 10;
    wire [3:0] b_one     = display_num % 10;

    seg_decode u_h (b_hundred, dec_hundred);
    seg_decode u_t (b_ten,     dec_ten);
    seg_decode u_o (b_one,     dec_one);

    reg [2:0] s_cnt;
    reg [7:0] seg_data_reg, seg_com_reg;
    assign seg_data = seg_data_reg;
    assign seg_com = seg_com_reg;

    always @(posedge clk) begin
        if(rst) s_cnt <= 0;
        else if(s_cnt >= 5) s_cnt <= 0;
        else s_cnt <= s_cnt + 1;
    end

    always @(posedge clk) begin
        if(rst) begin seg_com_reg <= 8'hFF; seg_data_reg <= 0; end
        else begin
            case(s_cnt)
                3'd0: begin seg_com_reg <= 8'b1111_1110; seg_data_reg <= dec_one;     end // 1의 자리
                3'd1: begin seg_com_reg <= 8'b1111_1101; seg_data_reg <= dec_ten;     end // 10의 자리
                3'd2: begin seg_com_reg <= 8'b1111_1011; seg_data_reg <= (b_hundred==0)? 8'h00 : dec_hundred; end // 100의 자리
                3'd3: begin seg_com_reg <= 8'b1111_0111; seg_data_reg <= 8'b0000_0000; end // 공백
                3'd4: begin seg_com_reg <= 8'b1110_1111; seg_data_reg <= 8'b1100_1110; end // 'P' (Play/Pulse)
                3'd5: begin seg_com_reg <= 8'b1101_1111; seg_data_reg <= 8'b0011_1110; end // 'b' (Beat)
                default: seg_com_reg <= 8'hFF;
            endcase
        end
    end

endmodule