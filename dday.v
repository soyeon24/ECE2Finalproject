module dday(
    input clk,
    input rst,
    input [9:0] sw_num,      // 날짜 설정용 스위치
    
    // 결과 출력
    output [7:0] seg_data,
    output [7:0] seg_com,
    output reg is_dday_alert // D-Day 당일 알림 신호
);

    // --------------------------------------------------------
    // 1. 목표 날짜 설정 (Month, Day)
    // --------------------------------------------------------
    reg [3:0] t_m_ten, t_m_one; // Target Month
    reg [3:0] t_d_ten, t_d_one; // Target Day
    
    parameter SET_M_TEN = 0, SET_M_ONE = 1, SET_D_TEN = 2, SET_D_ONE = 3, VIEW = 4;
    reg [2:0] state;

    // 스위치 입력 처리
    reg [9:0] sw_prev;
    wire [9:0] sw_rise = sw_num & ~sw_prev;
    reg [3:0] key_val;
    reg key_pressed;
    integer i;

    always @(posedge clk or posedge rst) begin
        if (rst) sw_prev <= 0;
        else sw_prev <= sw_num;
    end

    always @(*) begin
        key_val = 0; key_pressed = 0;
        for(i=0; i<10; i=i+1) if(sw_rise[i]) begin key_val = i; key_pressed = 1; end
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= SET_M_TEN;
            // 기본 목표: 12월 25일 (크리스마스)
            t_m_ten <= 1; t_m_one <= 2; t_d_ten <= 2; t_d_one <= 5;
        end else if (key_pressed) begin
            case (state)
                SET_M_TEN: begin t_m_ten <= (key_val > 1) ? 1 : key_val; state <= SET_M_ONE; end
                SET_M_ONE: begin t_m_one <= key_val; state <= SET_D_TEN; end
                SET_D_TEN: begin t_d_ten <= (key_val > 3) ? 3 : key_val; state <= SET_D_ONE; end
                SET_D_ONE: begin t_d_one <= key_val; state <= VIEW; end
                VIEW:      begin state <= SET_M_TEN; end // 다시 설정
            endcase
        end
    end

    // --------------------------------------------------------
    // 2. D-Day 계산 로직 (고정: 2025/12/12)
    // --------------------------------------------------------
    // 2025년 기준 각 월까지의 누적 일수 (평년)
    reg [8:0] acc_days; 
    wire [4:0] target_month = t_m_ten * 10 + t_m_one;
    wire [4:0] target_day   = t_d_ten * 10 + t_d_one;

    always @(*) begin
        case (target_month)
            1: acc_days = 0;   2: acc_days = 31;  3: acc_days = 59;
            4: acc_days = 90;  5: acc_days = 120; 6: acc_days = 151;
            7: acc_days = 181; 8: acc_days = 212; 9: acc_days = 243;
            10:acc_days = 273; 11:acc_days = 304; 12:acc_days = 334;
            default: acc_days = 0;
        endcase
    end

    // 현재 날짜(12/12)의 1월 1일부터의 일수 = 334 + 12 = 346일
    parameter CUR_TOTAL_DAYS = 346; 

    reg [8:0] target_total_days;
    reg [9:0] d_day_diff; // 남은 일수

    always @(*) begin
        target_total_days = acc_days + target_day;

        if (target_total_days == CUR_TOTAL_DAYS) begin
            d_day_diff = 0; // 당일
            is_dday_alert = 1;
        end else if (target_total_days > CUR_TOTAL_DAYS) begin
            d_day_diff = target_total_days - CUR_TOTAL_DAYS; // 같은 해 미래
            is_dday_alert = 0;
        end else begin
            // 내년으로 넘어감 (365일 더함)
            d_day_diff = (target_total_days + 365) - CUR_TOTAL_DAYS;
            is_dday_alert = 0;
        end
    end

    // --------------------------------------------------------
    // 3. 디스플레이 출력
    // --------------------------------------------------------
    wire [3:0] diff_hun = d_day_diff / 100;
    wire [3:0] diff_ten = (d_day_diff % 100) / 10;
    wire [3:0] diff_one = d_day_diff % 10;

    wire [7:0] dec_hun, dec_ten, dec_one;
    seg_decode u_h(diff_hun, dec_hun);
    seg_decode u_t(diff_ten, dec_ten);
    seg_decode u_o(diff_one, dec_one);

    // [수정된 부분] 설정 중일 때 보여줄 값 (변수명 통일)
    // 기존 코드: dec_tm_t, dec_tm_o, dec_td_t, dec_td_o
    // 수정 코드: dec_tm_ten, dec_tm_one, dec_td_ten, dec_td_one
    wire [7:0] dec_tm_ten, dec_tm_one, dec_td_ten, dec_td_one;
    
    seg_decode s1(t_m_ten, dec_tm_ten); 
    seg_decode s2(t_m_one, dec_tm_one);
    seg_decode s3(t_d_ten, dec_td_ten); 
    seg_decode s4(t_d_one, dec_td_one);

    reg [2:0] s_cnt;
    reg [7:0] seg_data_reg, seg_com_reg;
    assign seg_data = seg_data_reg;
    assign seg_com = seg_com_reg;

    always @(posedge clk) begin
        if (rst) s_cnt <= 0;
        else if (s_cnt >= 5) s_cnt <= 0;
        else s_cnt <= s_cnt + 1;
    end

    always @(posedge clk) begin
        if (rst) begin seg_com_reg <= 8'hFF; seg_data_reg <= 0; end
        else begin
            if (state != VIEW) begin 
                // [설정 모드] 현재 입력 중인 날짜 표시 (MM-DD)
                // 변수명을 위에서 수정한 것과 일치시킴
                case (s_cnt)
                    3'd0: begin seg_com_reg <= 8'b1111_1110; seg_data_reg <= dec_td_one; end
                    3'd1: begin seg_com_reg <= 8'b1111_1101; seg_data_reg <= dec_td_ten; end
                    3'd2: begin seg_com_reg <= 8'b1111_1011; seg_data_reg <= 8'b0100_0000; end // -
                    3'd3: begin seg_com_reg <= 8'b1111_0111; seg_data_reg <= dec_tm_one; end
                    3'd4: begin seg_com_reg <= 8'b1110_1111; seg_data_reg <= dec_tm_ten; end
                    default: seg_com_reg <= 8'hFF;
                endcase
            end else begin
                // [결과 모드]
                if (is_dday_alert) begin
                    // 당일: "d - d A Y"
                    case (s_cnt)
                        3'd0: begin seg_com_reg <= 8'b1111_1110; seg_data_reg <= 8'b0110_1110; end // 'Y'
                        3'd1: begin seg_com_reg <= 8'b1111_1101; seg_data_reg <= 8'b1110_1110; end // 'A'
                        3'd2: begin seg_com_reg <= 8'b1111_1011; seg_data_reg <= 8'b0111_1010; end // 'd'
                        3'd3: begin seg_com_reg <= 8'b1111_0111; seg_data_reg <= 8'b0100_0000; end // '-'
                        3'd4: begin seg_com_reg <= 8'b1110_1111; seg_data_reg <= 8'b0111_1010; end // 'd'
                        default: seg_com_reg <= 8'hFF;
                    endcase
                end else begin
                    // D-Day: "d - 1 5"
                    case (s_cnt)
                        3'd0: begin seg_com_reg <= 8'b1111_1110; seg_data_reg <= dec_one; end
                        3'd1: begin seg_com_reg <= 8'b1111_1101; seg_data_reg <= dec_ten; end
                        3'd2: begin seg_com_reg <= 8'b1111_1011; seg_data_reg <= (diff_hun==0)? 8'b0 : dec_hun; end
                        3'd3: begin seg_com_reg <= 8'b1111_0111; seg_data_reg <= 8'b0100_0000; end // '-'
                        3'd4: begin seg_com_reg <= 8'b1110_1111; seg_data_reg <= 8'b0111_1010; end // 'd'
                        default: seg_com_reg <= 8'hFF;
                    endcase
                end
            end
        end
    end
endmodule