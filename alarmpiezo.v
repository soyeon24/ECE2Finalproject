module alarmpiezo(
    input clk,               // 시스템 클럭 (1kHz 가정)
    input rst,
    input [9:0] sw_num,      // 시간 설정 및 알람 끄기(sw0)
   
    // watch.v에서 받아올 현재 시간
    input [3:0] cur_h_ten, cur_h_one,
    input [3:0] cur_m_ten, cur_m_one,
    input [3:0] cur_s_ten, cur_s_one,

    output [7:0] seg_data,
    output [7:0] seg_com,
    output reg alarm_led,    // 알람 LED
    output reg piezo         // 피에조 출력
);

    // 1. 알람 시간 저장 변수
    reg [3:0] alm_h_ten, alm_h_one, alm_m_ten, alm_m_one, alm_s_ten, alm_s_one;

    // [추가됨] 알람 상태 유지용 레지스터
    reg alarm_active;

    // 2. 시간 설정 로직
    parameter SET_H_TEN = 0, SET_H_ONE = 1, SET_M_TEN = 2, SET_M_ONE = 3, 
              SET_S_TEN = 4, SET_S_ONE = 5, DONE = 6;
    reg [2:0] state;
   
    reg [9:0] sw_prev;
    wire [9:0] sw_rise;
    reg [3:0] key_val;
    reg key_pressed;
    integer i;

    // 입력 감지 (Rising Edge Detection)
    always @(posedge clk or posedge rst) begin
        if (rst) sw_prev <= 0;
        else sw_prev <= sw_num;
    end
    assign sw_rise = sw_num & ~sw_prev; // 버튼을 누르는 순간

    always @(*) begin
        key_val = 0; key_pressed = 0;
        for(i=0; i<10; i=i+1) begin
            if(sw_rise[i]) begin 
                key_val = i; 
                key_pressed = 1; 
            end
        end
    end

    // 설정 상태 머신 (FSM)
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= SET_H_TEN;
            alm_h_ten <= 0; alm_h_one <= 0; alm_m_ten <= 0; 
            alm_m_one <= 0; alm_s_ten <= 0; alm_s_one <= 0;
        end else if (key_pressed) begin
            case (state)
                SET_H_TEN: begin alm_h_ten <= key_val; state <= SET_H_ONE; end
                SET_H_ONE: begin alm_h_one <= key_val; state <= SET_M_TEN; end
                SET_M_TEN: begin alm_m_ten <= (key_val>5)?5:key_val; state <= SET_M_ONE; end
                SET_M_ONE: begin alm_m_one <= key_val; state <= SET_S_TEN; end
                SET_S_TEN: begin alm_s_ten <= (key_val>5)?5:key_val; state <= SET_S_ONE; end
                SET_S_ONE: begin alm_s_one <= key_val; state <= DONE; end
                
                DONE: begin 
                    // [수정] 알람이 울리고 있지 않을 때만 다시 설정 모드로 진입 (첫 번째 코드와 동일 로직)
                    // 알람이 울릴 때 버튼을 누르면 시간이 바뀌는 게 아니라 알람이 꺼져야 하므로.
                    if (alarm_active == 0) begin
                        state <= SET_H_TEN; 
                        // 편의상 첫 입력값 바로 반영
                        alm_h_ten <= key_val;
                        state <= SET_H_ONE;
                    end
                end 
            endcase
        end
    end

    // 3. 알람 트리거 및 유지 로직 (Latching)
    wire is_match;
    assign is_match = (cur_h_ten == alm_h_ten && cur_h_one == alm_h_one &&
                       cur_m_ten == alm_m_ten && cur_m_one == alm_m_one &&
                       cur_s_ten == alm_s_ten && cur_s_one == alm_s_one);

    // [핵심 수정] 알람 상태 관리 (켜기/끄기)
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            alarm_active <= 0;
        end else begin
            // (1) 시간이 일치하고, 아직 안 켜져 있으면 켬
            if (is_match && !alarm_active) begin
                alarm_active <= 1;
            end
            // (2) 알람이 켜져 있을 때 SW0을 누르면 끔
            else if (alarm_active && sw_rise[0]) begin
                alarm_active <= 0;
            end
        end
    end

    // 4. 소리 및 LED 출력 로직
    reg [9:0] beep_cnt; // 삐- 소리 간격 조절용

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            alarm_led <= 0;
            beep_cnt <= 0;
            piezo <= 0;
        end else begin
            // [수정] is_match가 아니라 alarm_active를 확인
            if (alarm_active) begin
                // (1) LED 켜기
                alarm_led <= 1;

                // (2) 소리 패턴 (0.5초 소리 / 0.5초 침묵 - clk 1kHz 기준)
                if (beep_cnt < 999) beep_cnt <= beep_cnt + 1;
                else beep_cnt <= 0;

                if (beep_cnt < 500) begin
                    // 500Hz 톤 발생
                    piezo <= ~piezo; 
                end else begin
                    piezo <= 0;
                end

            end else begin
                // 알람 상태가 아니면 모두 끔
                alarm_led <= 0;
                beep_cnt <= 0;
                piezo <= 0;
            end
        end
    end

    // 5. 디스플레이 로직
    wire [7:0] dec_h_ten, dec_h_one, dec_m_ten, dec_m_one, dec_s_ten, dec_s_one;
    seg_decode u1(alm_h_ten, dec_h_ten); seg_decode u2(alm_h_one, dec_h_one);
    seg_decode u3(alm_m_ten, dec_m_ten); seg_decode u4(alm_m_one, dec_m_one);
    seg_decode u5(alm_s_ten, dec_s_ten); seg_decode u6(alm_s_one, dec_s_one);

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
        if(rst) begin seg_com_reg <= 8'b1111_1111; seg_data_reg <= 0; end
        else begin
            case(s_cnt)
                3'd0: begin seg_com_reg <= 8'b1111_1110; seg_data_reg <= dec_s_one; end
                3'd1: begin seg_com_reg <= 8'b1111_1101; seg_data_reg <= dec_s_ten; end
                3'd2: begin seg_com_reg <= 8'b1111_1011; seg_data_reg <= dec_m_one; end
                3'd3: begin seg_com_reg <= 8'b1111_0111; seg_data_reg <= dec_m_ten; end
                3'd4: begin seg_com_reg <= 8'b1110_1111; seg_data_reg <= dec_h_one; end
                3'd5: begin seg_com_reg <= 8'b1101_1111; seg_data_reg <= dec_h_ten; end
            endcase
        end
    end
endmodule