module timer(
    input clk,              // 시스템 클럭 (1kHz)
    input rst,              // 리셋
    input [9:0] sw_num,     // 숫자 입력용 스위치
    output reg [7:0] seg_data, 
    output reg [7:0] seg_com,
    output reg [7:0] led    // [NEW] LED 출력 포트 추가
);

    // ... (기존 변수 및 파라미터 선언 동일) ...
    // 시간 저장 변수 (HH:MM:SS)
    reg [3:0] h_ten, h_one, m_ten, m_one, s_ten, s_one;
    
    // 상태 정의
    parameter SET_H_TEN = 0, SET_H_ONE = 1;
    parameter SET_M_TEN = 2, SET_M_ONE = 3;
    parameter SET_S_TEN = 4, SET_S_ONE = 5;
    parameter RUNNING   = 6, DONE      = 7;
    
    reg [2:0] state;      // 현재 상태
    reg [9:0] ms_cnt;     // 밀리초 카운터 (0~999)

    // LED 깜빡임 제어용 카운터 [NEW]
    reg [9:0] led_blink_cnt; 

    // ... (스위치 입력 감지 및 입력값 판별 로직 동일 - 생략) ...
    // 스위치 엣지 검출용
    reg [9:0] sw_prev;
    wire [9:0] sw_rise;
    
    // 디스플레이용 변수
    reg [2:0] s_cnt;      
    wire [7:0] dec_h_ten, dec_h_one, dec_m_ten, dec_m_one, dec_s_ten, dec_s_one;

    // 2. 스위치 입력 감지 (Edge Detection)
    always @(posedge clk or posedge rst) begin
        if (rst) sw_prev <= 0;
        else sw_prev <= sw_num;
    end
    assign sw_rise = sw_num & ~sw_prev;

    // 3. 입력값 판별 (Priority Encoder)
    reg [3:0] key_val;
    reg key_pressed;
    integer i;

    always @(*) begin
        key_val = 0;
        key_pressed = 0;
        for(i = 0; i < 10; i = i + 1) begin
            if(sw_rise[i]) begin
                key_val = i; key_pressed = 1;
            end
        end
    end

    // -----------------------------------------------------
    // 4. 메인 상태 머신 & LED 제어 [수정됨]
    // -----------------------------------------------------
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= SET_H_TEN;
            h_ten <= 0; h_one <= 0; m_ten <= 0; m_one <= 0; s_ten <= 0; s_one <= 0;
            ms_cnt <= 0;
            led <= 8'b0000_0000;      // 리셋 시 LED 끔
            led_blink_cnt <= 0;
        end 
        else begin
            // [LED 제어 로직]
            if (state == DONE) begin
                led_blink_cnt <= led_blink_cnt + 1;
                if (led_blink_cnt < 500) led <= 8'b1111_1111; // 0.5초 켜짐
                else if (led_blink_cnt < 1000) led <= 8'b0000_0000; // 0.5초 꺼짐
                else led_blink_cnt <= 0;
            end else begin
                led <= 8'b0000_0000; // 타이머 실행 중엔 끔 (혹은 진행상황 표시 가능)
                led_blink_cnt <= 0;
            end

            // [상태 머신 로직]
            case (state)
                // ... (시간 설정 단계 - 기존과 동일) ...
                SET_H_TEN: if (key_pressed) begin h_ten <= key_val; state <= SET_H_ONE; end
                SET_H_ONE: if (key_pressed) begin h_one <= key_val; state <= SET_M_TEN; end
                SET_M_TEN: if (key_pressed) begin 
                    if (key_val > 5) m_ten <= 5; else m_ten <= key_val; 
                    state <= SET_M_ONE; 
                end
                SET_M_ONE: if (key_pressed) begin m_one <= key_val; state <= SET_S_TEN; end
                SET_S_TEN: if (key_pressed) begin 
                    if (key_val > 5) s_ten <= 5; else s_ten <= key_val; 
                    state <= SET_S_ONE; 
                end
                SET_S_ONE: if (key_pressed) begin 
                    s_one <= key_val; state <= RUNNING; 
                end

                RUNNING: begin
                    if (h_ten == 0 && h_one == 0 && m_ten == 0 && m_one == 0 && s_ten == 0 && s_one == 0) begin
                        state <= DONE; // 완료! -> 이제 LED 로직이 작동함
                    end
                    else if (ms_cnt >= 999) begin 
                        ms_cnt <= 0;
                        // ... (카운트다운 로직 - 기존과 동일) ...
                         if (s_one > 0) s_one <= s_one - 1;
                        else begin // s_one == 0
                            s_one <= 9;
                            if (s_ten > 0) s_ten <= s_ten - 1;
                            else begin // s_ten == 0
                                s_ten <= 5;
                                if (m_one > 0) m_one <= m_one - 1;
                                else begin // m_one == 0
                                    m_one <= 9;
                                    if (m_ten > 0) m_ten <= m_ten - 1;
                                    else begin // m_ten == 0
                                        m_ten <= 5;
                                        if (h_one > 0) h_one <= h_one - 1;
                                        else begin // h_one == 0
                                            h_one <= 9;
                                            if (h_ten > 0) h_ten <= h_ten - 1;
                                        end
                                    end
                                end
                            end
                        end
                    end 
                    else begin
                        ms_cnt <= ms_cnt + 1;
                    end
                end

                DONE: begin
                    // 종료 상태 유지 (LED는 위에서 제어됨)
                end
            endcase
        end
    end

    // ... (디코더 및 디스플레이 출력 부분 - 기존과 동일) ...
    seg_decode u_h_ten (h_ten, dec_h_ten);
    seg_decode u_h_one (h_one, dec_h_one);
    seg_decode u_m_ten (m_ten, dec_m_ten);
    seg_decode u_m_one (m_one, dec_m_one);
    seg_decode u_s_ten (s_ten, dec_s_ten);
    seg_decode u_s_one (s_one, dec_s_one);

    always @(posedge clk) begin
        if (rst) s_cnt <= 0;
        else if (s_cnt >= 5) s_cnt <= 0;
        else s_cnt <= s_cnt + 1;
    end

    always @(posedge clk) begin
        if (rst) begin
            seg_com <= 8'b1111_1111;
            seg_data <= 8'b0000_0000;
        end 
        else begin
             // 종료(DONE) 상태일 때 7-세그먼트 깜빡임 (선택 사항)
            if (state == DONE && ms_cnt > 500) begin // ms_cnt 대신 led_blink_cnt 써도 됨
                 seg_com <= 8'b1111_1111; 
            end
            else begin
                case (s_cnt)
                    3'd0: begin seg_com <= 8'b1111_1110; seg_data <= dec_s_one; end 
                    3'd1: begin seg_com <= 8'b1111_1101; seg_data <= dec_s_ten; end 
                    3'd2: begin seg_com <= 8'b1111_1011; seg_data <= dec_m_one; end 
                    3'd3: begin seg_com <= 8'b1111_0111; seg_data <= dec_m_ten; end 
                    3'd4: begin seg_com <= 8'b1110_1111; seg_data <= dec_h_one; end 
                    3'd5: begin seg_com <= 8'b1101_1111; seg_data <= dec_h_ten; end 
                    default: seg_com <= 8'b1111_1111;
                endcase
            end
        end
    end

endmodule