module setting (
    input clk,               // 시스템 클럭 (1kHz)
    input rst,               // 리셋
    input [9:0] sw_num,      // 숫자 입력용 스위치 0~9 (DIP 스위치 연결)
    
    // 7-세그먼트 출력 (현재 입력 상태를 보여줌)
    output [7:0] seg_data, 
    output [7:0] seg_com,
    
    // 최종 설정 결과
    output reg setting_done, // 설정 완료 후 1 클럭 펄스 발생
    output reg [23:0] set_time_value // 설정된 HH:MM:SS 값 (4비트 x 6개)
);

    // 내부 상태 정의
    parameter SET_H_TEN = 0, SET_H_ONE = 1;
    parameter SET_M_TEN = 2, SET_M_ONE = 3;
    parameter SET_S_TEN = 4, SET_S_ONE = 5;
    parameter HOLD      = 6; // 설정 완료 상태

    reg [2:0] state;        // 현재 설정 단계
    reg [3:0] h_ten, h_one, m_ten, m_one, s_ten, s_one; 

    // 스위치 엣지 검출 및 입력값 판별 로직 (timer.v와 동일)
    reg [9:0] sw_prev;
    wire [9:0] sw_rise;
    reg [3:0] key_val;
    reg key_pressed;
    integer i;

    // 디스플레이용
    reg [2:0] s_cnt;
    reg [7:0] seg_data_reg;
    reg [7:0] seg_com_reg;
    wire [7:0] dec_h_ten, dec_h_one, dec_m_ten, dec_m_one, dec_s_ten, dec_s_one;

    assign seg_data = seg_data_reg;
    assign seg_com = seg_com_reg;

    // -----------------------------------------------------
    // 1. 입력 감지 및 값 판별
    // -----------------------------------------------------
    always @(posedge clk or posedge rst) begin
        if (rst) sw_prev <= 0;
        else sw_prev <= sw_num;
    end
    assign sw_rise = sw_num & ~sw_prev;

    always @(*) begin
        key_val = 0;
        key_pressed = 0;
        for(i = 0; i < 10; i = i + 1) begin
            if(sw_rise[i]) begin
                key_pressed = 1;
                key_val = i;
            end
        end
    end

    // -----------------------------------------------------
    // 2. 설정 상태 머신
    // -----------------------------------------------------
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= SET_H_TEN;
            setting_done <= 0;
            h_ten <= 0; h_one <= 0; m_ten <= 0; m_one <= 0; s_ten <= 0; s_one <= 0;
        end 
        else begin
            setting_done <= 0; 

            if (key_pressed) begin
                case (state)
                    SET_H_TEN: begin h_ten <= key_val; state <= SET_H_ONE; end
                    SET_H_ONE: begin h_one <= key_val; state <= SET_M_TEN; end
                    SET_M_TEN: begin m_ten <= (key_val > 5) ? 5 : key_val; state <= SET_M_ONE; end
                    SET_M_ONE: begin m_one <= key_val; state <= SET_S_TEN; end
                    SET_S_TEN: begin s_ten <= (key_val > 5) ? 5 : key_val; state <= SET_S_ONE; end
                    SET_S_ONE: begin 
                        s_one <= key_val; 
                        state <= HOLD; 
                        setting_done <= 1; // 완료 시 펄스 발생
                    end
                    HOLD: ;
                endcase
            end
        end
    end

    // 3. 최종 값 출력 및 디코더 연결
    always @(*) begin
        set_time_value = {h_ten, h_one, m_ten, m_one, s_ten, s_one};
    end
    
    seg_decode u_h_ten (h_ten, dec_h_ten);
    seg_decode u_h_one (h_one, dec_h_one);
    seg_decode u_m_ten (m_ten, dec_m_ten);
    seg_decode u_m_one (m_one, dec_m_one);
    seg_decode u_s_ten (s_ten, dec_s_ten);
    seg_decode u_s_one (s_one, dec_s_one);

    // 4. 디스플레이 출력 (6자리 멀티플렉싱)
    always @(posedge clk) begin
        if (rst) s_cnt <= 0;
        else if (s_cnt >= 5) s_cnt <= 0;
        else s_cnt <= s_cnt + 1;
    end

    always @(posedge clk) begin
        if (rst) begin
            seg_com_reg <= 8'b1111_1111;
            seg_data_reg <= 8'b0000_0000;
        end 
        else begin
            case (s_cnt)
                3'd0: begin seg_com_reg <= 8'b1111_1110; seg_data_reg <= dec_s_one; end
                3'd1: begin seg_com_reg <= 8'b1111_1101; seg_data_reg <= dec_s_ten; end
                3'd2: begin seg_com_reg <= 8'b1111_1011; seg_data_reg <= dec_m_one; end
                3'd3: begin seg_com_reg <= 8'b1111_0111; seg_data_reg <= dec_m_ten; end
                3'd4: begin seg_com_reg <= 8'b1110_1111; seg_data_reg <= dec_h_one; end
                3'd5: begin seg_com_reg <= 8'b1101_1111; seg_data_reg <= dec_h_ten; end
                default: seg_com_reg <= 8'b1111_1111;
            endcase
            
            // 현재 입력할 자리는 깜빡이게 처리 (선택 사항)
            // 깜빡이는 효과를 위해 클럭 조건 추가 (clk)
            if (state < HOLD) begin
                if ((state == 0 && s_cnt == 5 && clk) ||
                    (state == 1 && s_cnt == 4 && clk) ||
                    (state == 2 && s_cnt == 3 && clk) ||
                    (state == 3 && s_cnt == 2 && clk) ||
                    (state == 4 && s_cnt == 1 && clk) ||
                    (state == 5 && s_cnt == 0 && clk))
                    seg_com_reg <= 8'b1111_1111; // 해당 자리 끄기 (깜빡임)
            end
        end
    end

endmodule