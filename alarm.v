module alarm(
    input clk, rst,
    input [9:0] sw_num,      // 시간 설정 및 알람 끄기(sw0)
    
    // watch.v에서 받아올 현재 시간
    input [3:0] cur_h_ten, cur_h_one,
    input [3:0] cur_m_ten, cur_m_one,
    input [3:0] cur_s_ten, cur_s_one,

    output [7:0] seg_data,
    output [7:0] seg_com,
    output alarm_led         // 알람 출력 신호
);

    // 1. 알람 시간 저장 변수
    reg [3:0] alm_h_ten, alm_h_one, alm_m_ten, alm_m_one, alm_s_ten, alm_s_one;
    
    // 알람 상태 유지용 레지스터
    reg alarm_active; 

    // 2. 시간 설정 상태 머신 정의
    parameter SET_H_TEN = 0, SET_H_ONE = 1, SET_M_TEN = 2, SET_M_ONE = 3, 
              SET_S_TEN = 4, SET_S_ONE = 5, DONE = 6;
    reg [2:0] state;
    
    // 스위치 입력 처리 (Edge Detection)
    reg [9:0] sw_prev;
    wire [9:0] sw_rise;
    reg [3:0] key_val;
    reg key_pressed;
    integer i;

    always @(posedge clk or posedge rst) begin
        if (rst) sw_prev <= 0;
        else sw_prev <= sw_num;
    end
    assign sw_rise = sw_num & ~sw_prev; // 버튼을 누르는 순간(Rising Edge)

    // 어떤 키가 눌렸는지 판별
    always @(*) begin
        key_val = 0; key_pressed = 0;
        for(i=0; i<10; i=i+1) begin
            if(sw_rise[i]) begin 
                key_val = i; 
                key_pressed = 1; 
            end
        end
    end

    // --------------------------------------------------------
    // 3. 설정 FSM (알람 시간 설정 로직)
    // --------------------------------------------------------
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
                    // [중요] 알람이 울리는 중이 아닐 때만 다시 설정 모드로 진입 가능
                    // 알람이 울릴 때는 버튼이 '알람 끄기' 용도로 쓰여야 함
                    if (alarm_active == 0) begin
                        state <= SET_H_TEN; 
                        // 첫 입력값 바로 반영 (편의성)
                        alm_h_ten <= key_val;
                        state <= SET_H_ONE; 
                    end
                end
            endcase
        end
    end

    // --------------------------------------------------------
    // 4. 알람 트리거 및 유지 로직 (Latching)
    // --------------------------------------------------------
    wire time_match;
    assign time_match = (cur_h_ten == alm_h_ten && cur_h_one == alm_h_one &&
                         cur_m_ten == alm_m_ten && cur_m_one == alm_m_one &&
                         cur_s_ten == alm_s_ten && cur_s_one == alm_s_one);

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            alarm_active <= 0;
        end else begin
            // (1) 시간이 일치하면 알람 켜기 (이미 켜져있지 않다면)
            if (time_match && !alarm_active) begin
                alarm_active <= 1;
            end
            // (2) 알람이 켜져있을 때 SW0을 누르면 끄기
            // sw_rise[0] 대신 sw_num[0]을 쓰면 누르고 있는 동안 꺼짐,
            // sw_rise[0]을 쓰면 누르는 순간 꺼짐. (여기선 확실한 종료를 위해 rise 사용)
            else if (alarm_active && sw_rise[0]) begin
                alarm_active <= 0;
            end
        end
    end

    assign alarm_led = alarm_active; // 외부 출력 연결

    // --------------------------------------------------------
    // 5. 디스플레이 로직 (설정된 알람 시간 표시)
    // --------------------------------------------------------
    wire [7:0] dec_h_ten, dec_h_one, dec_m_ten, dec_m_one, dec_s_ten, dec_s_one;
    
    // seg_decode 모듈 인스턴스 (제공해주신 코드 사용)
    seg_decode u1(alm_h_ten, dec_h_ten); 
    seg_decode u2(alm_h_one, dec_h_one);
    seg_decode u3(alm_m_ten, dec_m_ten); 
    seg_decode u4(alm_m_one, dec_m_one);
    seg_decode u5(alm_s_ten, dec_s_ten); 
    seg_decode u6(alm_s_one, dec_s_one);

    reg [2:0] s_cnt;
    reg [7:0] seg_data_reg, seg_com_reg;
    assign seg_data = seg_data_reg;
    assign seg_com = seg_com_reg;

    // 스캔 카운터
    always @(posedge clk) begin
        if(rst) s_cnt <= 0;
        else if(s_cnt >= 5) s_cnt <= 0;
        else s_cnt <= s_cnt + 1;
    end

    // 멀티플렉싱 출력
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
                default: seg_com_reg <= 8'b1111_1111;
            endcase
        end
    end

endmodule