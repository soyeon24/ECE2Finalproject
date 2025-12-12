module top_system (
    input clk, rst,
    input btn_star, input btn_hash,
    input sw_mode, input [9:0] sw_num,
    
    output reg [7:0] seg_data, output reg [7:0] seg_com,
    output lcd_e, output lcd_rs, output lcd_rw, output [7:0] lcd_data,
    
    output [7:0] led, 
    output piezo_out, 
    output servo_out
);
    wire [3:0] current_cursor; 
    wire is_app_running;
    
    wire btn_left = btn_star;
    wire btn_right = btn_hash;

    // 각 모듈의 7-세그먼트 화면 데이터들
    wire [7:0] watch_seg_data, watch_seg_com;
    wire [7:0] stop_seg_data,  stop_seg_com;
    wire [7:0] timer_seg_data, timer_seg_com; 
    wire [7:0] setting_seg_data, setting_seg_com;
    wire [7:0] world_seg_data, world_seg_com;
    wire [7:0] alarm_seg_data, alarm_seg_com;
    wire [7:0] date_seg_data, date_seg_com;
    wire [7:0] sound_seg_data, sound_seg_com;
    wire [7:0] metro_seg_data, metro_seg_com;
    wire [7:0] dday_seg_data, dday_seg_com;
    wire [7:0] react_seg_data, react_seg_com;
    
    // [중요] 에러 났던 부분! 여기서 선언해줘야 합니다.
    wire [7:0] music_seg_data, music_seg_com; // 11번 뮤직
    wire [7:0] lab_seg_data, lab_seg_com;     // 12번 랩 기록

    // [중요] 스톱워치 랩타임 데이터 전선
    wire [3:0] lap_m10, lap_m1, lap_s10, lap_s1;

    // 기타 신호들
    wire alarm_trigger;
    wire [7:0] timer_led;
    wire setting_done_pulse;
    wire [23:0] set_time_value;
    wire [3:0] w_h_ten, w_h_one, w_m_ten, w_m_one, w_s_ten, w_s_one;
    wire sound_alarm_trigger, sound_out_sig;
    wire metro_pwm_sig;
    wire is_dday_today;
    wire react_led_sig, react_piezo_sig;
    wire music_piezo_sig;
    
    wire [7:0] piano_seg_data, piano_seg_com;
    wire piano_piezo_sig;

    reg [127:0] text_row1, text_row2;

    // =====================================================
    // 2. 모듈 연결 (Instantiation)
    // =====================================================
    menu u_menu (
        .clk(clk), .rst(rst),
        .btn_left(btn_left), .btn_right(btn_right),
        .sw_mode(sw_mode), 
        .cursor_mode(current_cursor),
        .is_running(is_app_running)
    );

watch u_watch (
    .clk(clk), .rst(rst), 
    .load_time(setting_done_pulse), .load_value(set_time_value),
    .seg_data(watch_seg_data), .seg_com(watch_seg_com),
    .o_h_ten(w_h_ten), .o_h_one(w_h_one),
    .o_m_ten(w_m_ten), .o_m_one(w_m_one),
    .o_s_ten(w_s_ten), .o_s_one(w_s_one),
    .day_tick(day_change_sig) // [NEW] 신호 내보내기
);
    // [스톱워치 연결] 랩타임 내보내기
    stopwatch u_stopwatch (
        .clk(clk), .rst(rst),
        .start_btn(sw_num[0]), .stop_btn(sw_num[1]), .clear_btn(sw_num[2]),
        .lap_btn(sw_num[4]),   // SW4
        .seg_data(stop_seg_data), .seg_com(stop_seg_com),
        .o_lap_m_ten(lap_m10), .o_lap_m_one(lap_m1),
        .o_lap_s_ten(lap_s10), .o_lap_s_one(lap_s1)
    );

    timer u_timer (
        .clk(clk), .rst(rst), .sw_num(sw_num),
        .seg_data(timer_seg_data), .seg_com(timer_seg_com), .led(timer_led)
    );

    setting u_setting (
        .clk(clk), .rst(rst), .sw_num(sw_num),
        .setting_done(setting_done_pulse), .set_time_value(set_time_value),   
        .seg_data(setting_seg_data), .seg_com(setting_seg_com)
    );

    alarm u_alarm (
        .clk(clk), .rst(rst), .sw_num(sw_num),
        .cur_h_ten(w_h_ten), .cur_h_one(w_h_one), .cur_m_ten(w_m_ten), .cur_m_one(w_m_one), .cur_s_ten(w_s_ten), .cur_s_one(w_s_one),
        .seg_data(alarm_seg_data), .seg_com(alarm_seg_com), .alarm_led(alarm_trigger)
    );

    world_time u_world (
        .clk(clk), .rst(rst),
        .kst_h_ten(w_h_ten), .kst_h_one(w_h_one), .kst_m_ten(w_m_ten), .kst_m_one(w_m_one), .kst_s_ten(w_s_ten), .kst_s_one(w_s_one),
        .seg_data(world_seg_data), .seg_com(world_seg_com)
    );

    textlcd u_lcd (
        .clk(clk), .rst(rst),
        .line1_in(text_row1), .line2_in(text_row2), 
        .lcd_e(lcd_e), .lcd_rs(lcd_rs), .lcd_rw(lcd_rw), .lcd_data(lcd_data)
    );

   date u_date(
    .clk(clk), .rst(rst),
    .sw_num(sw_num),
    .day_tick(day_change_sig), // [NEW] 신호 받기
    .seg_data(date_seg_data), .seg_com(date_seg_com)
);

    // 알람 사운드 (기존 모듈)
    alarmpiezo u_alarm_sound (
        .clk(clk), .rst(rst), .sw_num(sw_num),
        // .sound_type(), // 필요시 연결
        .cur_h_ten(w_h_ten), .cur_h_one(w_h_one), .cur_m_ten(w_m_ten), .cur_m_one(w_m_one), .cur_s_ten(w_s_ten), .cur_s_one(w_s_one),
        .seg_data(sound_seg_data), .seg_com(sound_seg_com),
        .alarm_led(sound_alarm_trigger), .piezo(sound_out_sig)
    );

    metronome u_metronome (
        .clk(clk), .rst(rst), .sw_num(sw_num),
        .servo_pwm(metro_pwm_sig), .seg_data(metro_seg_data), .seg_com(metro_seg_com)
    );

    dday u_dday (
        .clk(clk), .rst(rst), .sw_num(sw_num),
        .seg_data(dday_seg_data), .seg_com(dday_seg_com), .is_dday_alert(is_dday_today)
    );

    reaction_game u_reaction (
        .clk(clk), .rst(rst),
        .game_btn(sw_num[0]), 
        .seg_data(react_seg_data), .seg_com(react_seg_com),
        .led_signal(react_led_sig), .piezo_signal(react_piezo_sig)
    );

    // 11번: 뮤직 플레이어 연결
    music u_music(
        .clk(clk), .rst(rst), .sw_num(sw_num),
        .seg_data(music_seg_data), .seg_com(music_seg_com),
        .piezo(music_piezo_sig)
    );

    // 12번: 랩타임 뷰어 연결 (스톱워치 값을 받음)
    lab_record u_lab_rec(
        .clk(clk), .rst(rst),
        .m_ten(lap_m10), .m_one(lap_m1), .s_ten(lap_s10), .s_one(lap_s1),
        .seg_data(lab_seg_data), .seg_com(lab_seg_com)
    );
    
    piano u_piano (
    .clk(clk),         // [주의] 여기에 50MHz 시스템 클럭 연결!
    .rst(rst),
    .sw_num(sw_num),   // SW0 ~ SW7 연결
    .piezo_out(piano_piezo_sig),
    .seg_data(piano_seg_data),
    .seg_com(piano_seg_com)
);


    // =====================================================
    // 3. 출력 MUX
    // =====================================================
    
    // (A) 피에조 MUX
    assign piezo_out = (is_app_running && current_cursor == 4'd7) ? sound_out_sig : 
                       (is_app_running && current_cursor == 4'd9 && is_dday_today) ? clk : 
                       (is_app_running && current_cursor == 4'd10) ? (react_piezo_sig ? clk : 1'b0) :
                       (is_app_running && current_cursor == 4'd11) ? music_piezo_sig :
                       (is_app_running && current_cursor == 4'd13) ? piano_piezo_sig : 
                       1'b0;
                       

    assign servo_out = metro_pwm_sig;

    // (B) 7-세그먼트 MUX
    always @(*) begin
        if (is_app_running) begin
            case (current_cursor)
                4'd0: begin seg_data = watch_seg_data; seg_com = watch_seg_com; end
                4'd1: begin seg_data = stop_seg_data; seg_com = stop_seg_com; end
                4'd2: begin seg_data = timer_seg_data; seg_com = timer_seg_com; end
                4'd3: begin seg_data = setting_seg_data; seg_com = setting_seg_com; end
                4'd4: begin seg_data = world_seg_data; seg_com = world_seg_com; end
                4'd5: begin seg_data = alarm_seg_data; seg_com = alarm_seg_com; end
                4'd6: begin seg_data = date_seg_data; seg_com = date_seg_com; end 
                4'd7: begin seg_data = sound_seg_data; seg_com = sound_seg_com; end 
                4'd8: begin seg_data = metro_seg_data; seg_com = metro_seg_com; end
                4'd9: begin seg_data = dday_seg_data; seg_com = dday_seg_com; end
                4'd10: begin seg_data = react_seg_data; seg_com = react_seg_com; end
                
                // [추가] 11번, 12번 메뉴 화면 연결
                4'd11: begin seg_data = music_seg_data; seg_com = music_seg_com; end
                4'd12: begin seg_data = lab_seg_data; seg_com = lab_seg_com; end
                
                // case (current_cursor) 내부에 추가
                4'd13: begin seg_data = piano_seg_data; seg_com = piano_seg_com; end
                
                default: begin seg_data = 0; seg_com = 8'hFF; end
            endcase
        end else begin
            seg_data = 0; seg_com = 8'hFF;
        end
    end

    // (C) LCD 텍스트 MUX
    always @(*) begin
        if (is_app_running == 0) begin
            text_row1 = "   SELECT MODE  ";
            case (current_cursor)
                4'd0: text_row2 = " <    WATCH   > ";
                4'd1: text_row2 = " <  STOPWATCH > ";
                4'd2: text_row2 = " <    TIMER   > ";
                4'd3: text_row2 = " <   SETTING  > ";
                4'd4: text_row2 = " <  WORLD TIME> ";
                4'd5: text_row2 = " <    ALARM   > ";
                4'd6: text_row2 = " <    DATE    > ";
                4'd7: text_row2 = " < SOUND ALARM> ";
                4'd8: text_row2 = " <  METRONOME > ";
                4'd9: text_row2 = " < D-DAY CNT  > ";
                4'd10: text_row2 = " < REACTION GM> ";
                
                // [추가] 메뉴 선택 시 이름 표시
                4'd11: text_row2 = " < MUSIC PLAYER > ";
                4'd12: text_row2 = " <  LAB RECORD  > "; 
                4'd13: text_row2 = " <  PIANO PLAY  > ";
                
                default: text_row2 = "                ";
            endcase
        end else begin
            case (current_cursor)
                4'd0: begin text_row1 = "   WATCH MODE   "; text_row2 = " Look at 7-Seg  "; end
                4'd1: begin text_row1 = " STOPWATCH RUN  "; text_row2 = " Go:0Stop1rst2  "; end
                4'd2: begin text_row1 = "   TIMER MODE   "; text_row2 = " Set Time SW0-9 "; end
                4'd3: begin text_row1 = "    SETTING     "; text_row2 = " HH:MM:SS SW0-9 "; end
                4'd4: begin text_row1 = "   WORLD TIME   "; text_row2 = "   UTC (GMT)    "; end
                4'd5: begin text_row1 = "   ALARM MODE   "; text_row2 = "   hh:mm:ss     "; end
                4'd6: begin text_row1 = "   TODAY DATE   "; text_row2 = "   Look at 7-Seg   "; end
                4'd7: begin text_row1 = "  SOUND ALARM   "; text_row2 = "   hh:mm:ss     "; end
                4'd8: begin text_row1 = "   METRONOME    "; text_row2 = " SW0:60 SW1:90  "; end
                4'd9: begin text_row1 = "  D-DAY COUNTER "; text_row2 = " Set Target M-D "; end
                4'd10: begin text_row1 = " REACTION GAME! "; text_row2 = " Press SW0 Fast "; end
                
                // [추가] 11번, 12번 메뉴 실행 시 LCD
                4'd11: begin 
                    text_row1 = "  MUSIC PLAYER  "; 
                    text_row2 = " SW1~5:Play 0:X "; 
                end
                4'd12: begin 
                    text_row1 = "   LAB RECORD   ";
                    text_row2 = { "   ", 
                                  (lap_m10 + 8'h30), (lap_m1 + 8'h30), ":", 
                                  (lap_s10 + 8'h30), (lap_s1 + 8'h30), 
                                  "        " }; 
                end
                4'd13: begin 
                    text_row1 = "   PIANO MODE   "; 
                    text_row2 = " SW0-7: DoReMiFa"; 
                end

                default: begin text_row1 = "     Running    "; text_row2 = "                "; end
            endcase
        end
    end

    // (D) LED 출력
    assign led = (is_app_running && current_cursor == 4'd2) ? timer_led : 
                 (is_app_running && current_cursor == 4'd5) ? {8{alarm_trigger}} : 
                 (is_app_running && current_cursor == 4'd7) ? {7'b0, sound_alarm_trigger} : 
                 (is_app_running && current_cursor == 4'd9 && is_dday_today) ? 8'b1111_1111 : 
                 (is_app_running && current_cursor == 4'd10) ? {8{react_led_sig}} :
                 8'b0;

endmodule