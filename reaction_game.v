module reaction_game(
    input clk,              // 1kHz Clock
    input rst,
    input game_btn,         // 게임 버튼 (sw_num[0] 사용 예정)
    
    output [7:0] seg_data,
    output [7:0] seg_com,
    output reg led_signal,  // 시각 신호 (LED)
    output reg piezo_signal // 청각 신호 (Piezo)
);

    // --------------------------------------------------------
    // 1. 상태 및 변수 정의
    // --------------------------------------------------------
    parameter S_IDLE  = 0; // 대기 (Ready 표시)
    parameter S_WAIT  = 1; // 랜덤 대기 중 (화면 꺼짐, 긴장감 조성)
    parameter S_GO    = 2; // 신호 발생! (시간 측정)
    parameter S_DONE  = 3; // 결과 표시
    parameter S_FAIL  = 4; // 너무 빨리 누름 (부정 출발)

    reg [2:0] state;
    reg [12:0] wait_cnt;    // 랜덤 대기 카운터 (최대 5000ms)
    reg [12:0] random_seed; // 랜덤 시드 생성용 (계속 돌아가는 카운터)
    reg [9:0] react_time;   // 반응 시간 기록 (ms 단위, 최대 999ms)

    // 버튼 엣지 검출
    reg btn_prev;
    wire btn_click = game_btn && !btn_prev;
    always @(posedge clk) begin
        if(rst) btn_prev <= 0;
        else btn_prev <= game_btn;
    end

    // --------------------------------------------------------
    // 2. 랜덤 시드 생성기
    // --------------------------------------------------------
    // 2초(2000ms) ~ 5초(5000ms) 사이를 계속 왕복하는 카운터
    // 사용자가 버튼을 누르는 시점의 이 값을 대기 시간으로 사용함
    always @(posedge clk or posedge rst) begin
        if (rst) random_seed <= 2000;
        else begin
            if (random_seed >= 5000) random_seed <= 2000;
            else random_seed <= random_seed + 1;
        end
    end

    // --------------------------------------------------------
    // 3. 메인 게임 로직
    // --------------------------------------------------------
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= S_IDLE;
            led_signal <= 0;
            piezo_signal <= 0;
            react_time <= 0;
            wait_cnt <= 0;
        end else begin
            case (state)
                S_IDLE: begin
                    led_signal <= 0;
                    piezo_signal <= 0;
                    // 버튼 누르면 게임 시작
                    if (btn_click) begin
                        wait_cnt <= random_seed; // 현재 시드값을 대기 시간으로 설정
                        state <= S_WAIT;
                    end
                end

                S_WAIT: begin
                    // 대기 시간 카운트 다운
                    if (btn_click) begin
                        // 신호 오기 전에 누름 -> 실패
                        state <= S_FAIL;
                    end else if (wait_cnt == 0) begin
                        // 대기 끝 -> 신호 발생!
                        state <= S_GO;
                        react_time <= 0;
                        led_signal <= 1;   // LED 켬
                        piezo_signal <= 1; // 소리 켬
                    end else begin
                        wait_cnt <= wait_cnt - 1;
                    end
                end

                S_GO: begin
                    // 100ms 정도만 소리 울리고 끄기 (짧은 '삑!')
                    if (react_time > 100) piezo_signal <= 0;

                    // 반응 시간 측정
                    if (btn_click) begin
                        state <= S_DONE;
                        led_signal <= 0;
                        piezo_signal <= 0;
                    end else if (react_time >= 999) begin
                        // 1초 넘어가면 그냥 종료 (너무 느림)
                        state <= S_DONE;
                        led_signal <= 0;
                        piezo_signal <= 0;
                    end else begin
                        react_time <= react_time + 1;
                    end
                end

                S_DONE: begin
                    // 결과 확인 후 버튼 누르면 다시 처음으로
                    if (btn_click) state <= S_IDLE;
                end

                S_FAIL: begin
                    // 실패 메시지 확인 후 버튼 누르면 다시 처음으로
                    if (btn_click) state <= S_IDLE;
                end
            endcase
        end
    end

    // --------------------------------------------------------
    // 4. 디스플레이 출력
    // --------------------------------------------------------
    // 반응 시간 숫자 분리
    wire [3:0] r_hun = react_time / 100;
    wire [3:0] r_ten = (react_time % 100) / 10;
    wire [3:0] r_one = react_time % 10;
    
    wire [7:0] dec_hun, dec_ten, dec_one;
    seg_decode u1(r_hun, dec_hun);
    seg_decode u2(r_ten, dec_ten);
    seg_decode u3(r_one, dec_one);

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
            case (state)
                S_IDLE: begin // "rEAdy"
                    case(s_cnt)
                        3'd0: begin seg_com_reg <= 8'b1111_1110; seg_data_reg <= 8'b0110_1110; end // y
                        3'd1: begin seg_com_reg <= 8'b1111_1101; seg_data_reg <= 8'b0111_1010; end // d
                        3'd2: begin seg_com_reg <= 8'b1111_1011; seg_data_reg <= 8'b1110_1110; end // A
                        3'd3: begin seg_com_reg <= 8'b1111_0111; seg_data_reg <= 8'b1001_1110; end // E
                        3'd4: begin seg_com_reg <= 8'b1110_1111; seg_data_reg <= 8'b0000_1010; end // r
                        default: seg_com_reg <= 8'hFF;
                    endcase
                end
                S_WAIT: begin // 화면 끔 (긴장감)
                    seg_com_reg <= 8'hFF; 
                end
                S_GO: begin // "Go"
                     case(s_cnt)
                        3'd2: begin seg_com_reg <= 8'b1111_1011; seg_data_reg <= 8'b1111_1100; end // o
                        3'd3: begin seg_com_reg <= 8'b1111_0111; seg_data_reg <= 8'b1011_1100; end // G
                        default: seg_com_reg <= 8'hFF;
                    endcase
                end
                S_DONE: begin // 결과 값 (예: 0.235)
                    case(s_cnt)
                        3'd0: begin seg_com_reg <= 8'b1111_1110; seg_data_reg <= dec_one; end
                        3'd1: begin seg_com_reg <= 8'b1111_1101; seg_data_reg <= dec_ten; end
                        3'd2: begin seg_com_reg <= 8'b1111_1011; seg_data_reg <= dec_hun; end
                        3'd3: begin seg_com_reg <= 8'b1111_0111; seg_data_reg <= 8'b1000_0000; end // .
                        3'd4: begin seg_com_reg <= 8'b1110_1111; seg_data_reg <= 8'b1111_1100; end // 0
                        default: seg_com_reg <= 8'hFF;
                    endcase
                end
                S_FAIL: begin // "FAIL"
                    case(s_cnt)
                        3'd0: begin seg_com_reg <= 8'b1111_1110; seg_data_reg <= 8'b0001_1100; end // L
                        3'd1: begin seg_com_reg <= 8'b1111_1101; seg_data_reg <= 8'b0110_0000; end // I
                        3'd2: begin seg_com_reg <= 8'b1111_1011; seg_data_reg <= 8'b1110_1110; end // A
                        3'd3: begin seg_com_reg <= 8'b1111_0111; seg_data_reg <= 8'b1000_1110; end // F
                        default: seg_com_reg <= 8'hFF;
                    endcase
                end
            endcase
        end
    end
endmodule