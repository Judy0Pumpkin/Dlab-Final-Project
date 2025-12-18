`timescale 1ns / 1ps

module lab10(
    input  clk,
    input  reset_n,
    input  [3:0] usr_btn,
    input  [3:0] usr_sw,
    output [3:0] usr_led,
    
    input  uart_rx,
    output uart_tx,
    
    // VGA ports
    output VGA_HSYNC,
    output VGA_VSYNC,
    output [3:0] VGA_RED,
    output [3:0] VGA_GREEN,
    output [3:0] VGA_BLUE,
    
    // LCD ports
    output LCD_RS,
    output LCD_RW,
    output LCD_E,
    output [3:0] LCD_D
);

//========================================================================
// Parameters
//========================================================================
localparam VBUF_W = 320;
localparam VBUF_H = 240;
localparam GRID_SIZE = 20;
localparam GRID_W = 16;
localparam GRID_H = 12;

localparam SNAKE_INIT_LEN = 5;
localparam SNAKE_MAX_LEN = 100;  
localparam SNAKE_INIT_X = 8;
localparam SNAKE_INIT_Y = 6;
localparam SNAKE_SKIN_SIZE = 20;
localparam TOTAL_SNAKE_SKIN_SIZE = 1200;

localparam DIR_RIGHT = 2'd0;
localparam DIR_DOWN  = 2'd1;
localparam DIR_LEFT  = 2'd2;
localparam DIR_UP    = 2'd3;

localparam STATE_INIT    = 2'd0;
localparam STATE_PLAYING = 2'd1;
localparam STATE_GAMEOVER = 2'd2;

localparam FRUIT_SIZE = 20;
localparam TOTAL_FRUIT_SIZE = 400;

localparam LIGHTNING_SIZE = 400; 
localparam SPEED_NORMAL = 27'd50_000_000; 
localparam SPEED_FAST   = 27'd33_333_333; 
localparam BOOST_DURATION = 29'd500_000_000; 

localparam TOTAL_SCORE_TEXT_SIZE = 1200;
localparam TOTAL_SCORE_NUM_SIZE = 4000;

localparam OBSTACLE_NUM = 5;
localparam OBSTACLE_SIZE = 20;
localparam TOTAL_OBSTACLE_SIZE = 400;

localparam PORTAL_SIZE = 400; 
localparam QUESTION_SIZE = 400; 

localparam START_W = 267;
localparam START_H = 49;
localparam START_SIZE = 13083;

localparam MAP_ICON_W = 72;
localparam MAP_ICON_H = 38;
localparam MAP_ICON_SIZE = 2736;

localparam OVER_W = 246;
localparam OVER_H = 28;
localparam OVER_SIZE = 6888;

localparam CHOOSE_W = 183;      
localparam CHOOSE_H = 21;      
localparam CHOOSE_SIZE = 3843;

localparam PREVIEW_X = 280;
localparam PREVIEW_Y = 150;
//========================================================================
// Signal Declarations
//========================================================================
wire [3:0] btn_pressed, last_btn, now_btn;

wire vga_clk, video_on, pixel_tick;
wire [9:0] pixel_x, pixel_y;
reg  [11:0] rgb_reg, rgb_next;

wire [11:0] bg_data, skin_data, fruit_data, score_text_data, score_num_data, obstacle_data, question_data, lightning_data, portal_data, data_in;
wire [17:0] bg_addr, skin_addr, fruit_addr, score_text_addr, score_num_addr, obstacle_addr;
wire [17:0] lightning_addr, portal_addr; 
wire [8:0] question_addr_wire;

wire sram_we, sram_en;

reg [1:0] game_state;
reg [1:0] snake_direction, next_direction;
reg direction_changed;

reg [5:0] snake_x [0:SNAKE_MAX_LEN-1];
reg [5:0] snake_y [0:SNAKE_MAX_LEN-1];
reg [6:0] snake_length;

wire [5:0] pre_portal_x, pre_portal_y;
wire [5:0] next_head_x, next_head_y;

reg [1:0] curr_skin_index;      
reg [1:0] actual_skin_index;    
reg is_random_skin_mode;        
wire [17:0] skin_addr_base;     
wire [1:0] rand_skin_val;       

reg [5:0] fruit_x, fruit_y;
wire [5:0] rand_x, rand_y;
reg fruit_vaild, fruit_on_field, fruit_eat;

reg [5:0] lightning_x, lightning_y;
wire [5:0] rand_L_x, rand_L_y;
reg lightning_valid, lightning_on_field, lightning_eat;
reg [28:0] boost_timer; 
wire is_lightning;

reg [3:0] obstacle_pos_x[0:4], obstacle_pos_y[0:4];
reg [4:0] obstacle_valid; 
reg is_hitting_obstacle; 

reg [5:0] portal1_x, portal1_y;
reg [5:0] portal2_x, portal2_y;
wire is_portal1, is_portal2;

reg [7:0] score_10, score_1, score;
reg [17:0] score_addr_base;


reg [26:0] move_counter;
wire [26:0] current_speed_limit; 
wire move_tick;

wire collision, self_collision, wall_collision, obstacle_collision;
reg self_collision_reg;
wire [5:0] current_grid_x;
wire [5:0] current_grid_y;
wire is_snake, is_fruit, is_score_text, is_score_num_1, is_score_num_10, is_obstacle;
reg is_snake_reg;

wire transmit, received;
wire [7:0] rx_byte;
reg uart_data_read;
wire is_receiving, is_transmitting, recv_error;

// LCD signals
reg [127:0] row_A;
reg [127:0] row_B;

integer i;

assign usr_led = fruit_x;
assign uart_tx = 1'b1;

wire [11:0] start_data, map1_img_data, map2_img_data, over_data, choose_data;
wire [17:0] start_addr, map1_img_addr, map2_img_addr, over_addr, choose_addr;

//========================================================================
// Debounce
//========================================================================
debounce #(.DEBOUNCE_PERIOD(2_000_000)) btn_db0 (
    .clk(clk), .btn_input(usr_btn[0]), .btn_output(now_btn[0])
);
debounce #(.DEBOUNCE_PERIOD(2_000_000)) btn_db1 (
    .clk(clk), .btn_input(usr_btn[1]), .btn_output(now_btn[1])
);
debounce #(.DEBOUNCE_PERIOD(2_000_000)) btn_db2 (
    .clk(clk), .btn_input(usr_btn[2]), .btn_output(now_btn[2])
);
debounce #(.DEBOUNCE_PERIOD(2_000_000)) btn_db3 (
    .clk(clk), .btn_input(usr_btn[3]), .btn_output(now_btn[3])
);

assign last_btn = now_btn;
assign btn_pressed = ~last_btn & now_btn; 
//========================================================================
// SRAM
//========================================================================

sram #( .DATA_WIDTH(12), .ADDR_WIDTH(18), .RAM_SIZE(TOTAL_SNAKE_SKIN_SIZE), .MEM_FILE("skin.mem") ) ram_skin (
    .clk(clk), .we(sram_we), .en(sram_en), .addr(skin_addr), .data_i(data_in), .data_o(skin_data)
);

sram #( .DATA_WIDTH(12), .ADDR_WIDTH(9), .RAM_SIZE(QUESTION_SIZE), .MEM_FILE("question.mem") ) ram_question (
    .clk(clk), .we(sram_we), .en(sram_en), .addr(question_addr_wire), .data_i(data_in), .data_o(question_data)
);

sram #( .DATA_WIDTH(12), .ADDR_WIDTH(18), .RAM_SIZE(LIGHTNING_SIZE), .MEM_FILE("lightning.mem") ) ram_lightning (
    .clk(clk), .we(sram_we), .en(sram_en), .addr(lightning_addr), .data_i(data_in), .data_o(lightning_data)
);

sram #( .DATA_WIDTH(12), .ADDR_WIDTH(18), .RAM_SIZE(PORTAL_SIZE), .MEM_FILE("portal.mem") ) ram_portal (
    .clk(clk), .we(sram_we), .en(sram_en), .addr(portal_addr), .data_i(data_in), .data_o(portal_data)
);

sram #( .DATA_WIDTH(12), .ADDR_WIDTH(18), .RAM_SIZE(TOTAL_FRUIT_SIZE), .MEM_FILE("fruit.mem") ) ram_fruit (
    .clk(clk), .we(sram_we), .en(sram_en), .addr(fruit_addr), .data_i(data_in), .data_o(fruit_data)
);

sram #(
    .DATA_WIDTH(12), 
    .ADDR_WIDTH(18), 
    .RAM_SIZE(TOTAL_SCORE_TEXT_SIZE),
    .MEM_FILE("score_text.mem")
) ram_score_text (
    .clk(clk), 
    .we(sram_we), 
    .en(sram_en),
    .addr(score_text_addr), 
    .data_i(data_in), 
    .data_o(score_text_data)
);

sram #(
    .DATA_WIDTH(12), 
    .ADDR_WIDTH(18), 
    .RAM_SIZE(TOTAL_SCORE_NUM_SIZE),
    .MEM_FILE("score_num.mem")
) ram_score_num (
    .clk(clk), 
    .we(sram_we), 
    .en(sram_en),
    .addr(score_num_addr), 
    .data_i(data_in), 
    .data_o(score_num_data)
);

sram #(
    .DATA_WIDTH(12), 
    .ADDR_WIDTH(18), 
    .RAM_SIZE(TOTAL_OBSTACLE_SIZE),
    .MEM_FILE("obstacle.mem")
) ram_obstacle (
    .clk(clk), 
    .we(sram_we), 
    .en(sram_en),
    .addr(obstacle_addr), 
    .data_i(data_in), 
    .data_o(obstacle_data)
);
assign sram_we = 1'b0;
assign sram_en = 1'b1;
assign data_in = 12'h000;

sram #(
    .DATA_WIDTH(12), 
    .ADDR_WIDTH(18), 
    .RAM_SIZE(START_SIZE), 
    .MEM_FILE("gamestart.mem")
) ram_start (
    .clk(clk), 
    .we(1'b0), 
    .en(1'b1), 
    .addr(start_addr), 
    .data_i(12'h0), 
    .data_o(start_data)
);

sram #(
    .DATA_WIDTH(12), 
    .ADDR_WIDTH(18), 
    .RAM_SIZE(MAP_ICON_SIZE), 
    .MEM_FILE("map1.mem")
) ram_map1_img (
    .clk(clk), 
    .we(1'b0), 
    .en(1'b1), 
    .addr(map1_img_addr), 
    .data_i(12'h0), 
    .data_o(map1_img_data)
);

sram #(
    .DATA_WIDTH(12), 
    .ADDR_WIDTH(18), 
    .RAM_SIZE(MAP_ICON_SIZE), 
    .MEM_FILE("map2.mem")
) ram_map2_img (
    .clk(clk), 
    .we(1'b0), 
    .en(1'b1), 
    .addr(map2_img_addr), 
    .data_i(12'h0), 
    .data_o(map2_img_data)
);

sram #(
    .DATA_WIDTH(12), 
    .ADDR_WIDTH(18), 
    .RAM_SIZE(OVER_SIZE),     
    .MEM_FILE("gameover.mem")  
) ram_over (
    .clk(clk), 
    .we(1'b0), 
    .en(1'b1), 
    .addr(over_addr), 
    .data_i(12'h0), 
    .data_o(over_data)
);

sram #(
    .DATA_WIDTH(12), 
    .ADDR_WIDTH(18), 
    .RAM_SIZE(CHOOSE_SIZE),      
    .MEM_FILE("choose.mem")   
) ram_choose (
    .clk(clk), 
    .we(1'b0), 
    .en(1'b1), 
    .addr(choose_addr), 
    .data_i(12'h0), 
    .data_o(choose_data)
);

//========================================================================
// VGA Controller
//========================================================================
vga_sync vs0(
    .clk(vga_clk), 
    .reset(~reset_n), 
    .oHS(VGA_HSYNC), 
    .oVS(VGA_VSYNC),
    .visible(video_on), 
    .p_tick(pixel_tick),
    .pixel_x(pixel_x), 
    .pixel_y(pixel_y)
);

clk_divider #(2) clk_divider0(
    .clk(clk),
    .reset(~reset_n),
    .clk_out(vga_clk)
);

//========================================================================
// UART
//========================================================================
uart uart_inst(
    .clk(clk),
    .rst(~reset_n),
    .rx(uart_rx),
    .tx(),
    .transmit(transmit),
    .tx_byte(8'h00),
    .received(received),
    .rx_byte(rx_byte),
    .is_receiving(is_receiving),
    .is_transmitting(is_transmitting),
    .recv_error(recv_error)
);

assign transmit = 1'b0;

//========================================================================
// Random Generators
//========================================================================
random_num #( .mod(3) ) random_skin_gen ( .clk(clk), .rst(~reset_n), .rand_num(rand_skin_val) );
random_num #( .mod(14) ) random_fruit_x ( .clk(clk), .rst(~reset_n), .rand_num(rand_x) );
random_num #( .mod(10) ) random_fruit_y ( .clk(clk), .rst(~reset_n), .rand_num(rand_y) );
random_num #( .mod(13) ) random_lightning_x ( .clk(clk), .rst(~reset_n), .rand_num(rand_L_x) );
random_num #( .mod(9) ) random_lightning_y ( .clk(clk), .rst(~reset_n), .rand_num(rand_L_y) );

//========================================================================
// Skin Selection
//========================================================================
always @(posedge clk) begin
    if (~reset_n) begin
        curr_skin_index <= 2'd0;
        actual_skin_index <= 2'd0;
        is_random_skin_mode <= 1'b0;
    end else begin
        is_random_skin_mode <= ~usr_sw[3]; 

        if (game_state == STATE_INIT) begin
            if (usr_sw[1])      curr_skin_index <= 2'd1; 
            else if (usr_sw[2]) curr_skin_index <= 2'd2;
            else                curr_skin_index <= 2'd0;
            
            if (~usr_sw[3]) actual_skin_index <= rand_skin_val; 
            else            actual_skin_index <= curr_skin_index;
        end
        else if (game_state == STATE_PLAYING) begin
            if (~usr_sw[3] && fruit_eat) begin
                if (rand_skin_val == actual_skin_index)
                    actual_skin_index <= (rand_skin_val == 2'd2) ? 2'd0 : rand_skin_val + 1;
                else
                    actual_skin_index <= rand_skin_val;
            end
        end
    end
end

assign skin_addr_base = (actual_skin_index == 2'd1) ? 18'd400 : (actual_skin_index == 2'd2) ? 18'd800 : 18'd0;

//========================================================================
// Game State Machine
//========================================================================
always @(posedge clk) begin
    if (~reset_n) begin
        game_state <= STATE_INIT;
    end else begin
        case (game_state)
            STATE_INIT: if (btn_pressed) game_state <= STATE_PLAYING;
            STATE_PLAYING: if (collision || score == 0) game_state <= STATE_GAMEOVER;
            STATE_GAMEOVER: if (btn_pressed || received) game_state <= STATE_INIT;
            default:       game_state <= STATE_INIT;
        endcase
    end
end

//========================================================================
// Snake Initialization
//========================================================================
always @(posedge clk) begin
    if (~reset_n || game_state == STATE_INIT) begin
        // Initialize snake
        snake_length <= SNAKE_INIT_LEN;
        snake_direction <= DIR_RIGHT;
        next_direction <= DIR_RIGHT;
        direction_changed <= 1'b0;
        uart_data_read <= 1'b0;
        obstacle_valid <= 5'b11111; 

        if (usr_sw[0] == 1'b1) begin
            portal1_x <= 2;  portal1_y <= 2;
            portal2_x <= 13; portal2_y <= 9;
        end 
        else begin
            portal1_x <= 2;  portal1_y <= 9;
            portal2_x <= 13; portal2_y <= 2;
        end

        for (i = 0; i < SNAKE_MAX_LEN; i = i + 1) begin
            if (i < SNAKE_INIT_LEN) begin
                snake_x[i] <= SNAKE_INIT_X - i;
                snake_y[i] <= SNAKE_INIT_Y;
            end else begin
                snake_x[i] <= 5'd0;
                snake_y[i] <= 5'd0;
            end
        end
    end else if (game_state == STATE_PLAYING) begin
        
        // Input Control
        if (!direction_changed) begin
            if (received && !uart_data_read) begin
                uart_data_read <= 1'b1;
                case (rx_byte)
                    8'h77, 8'h57: if (snake_direction != DIR_DOWN) begin next_direction <= DIR_UP; direction_changed <= 1'b1; end
                    8'h73, 8'h53: if (snake_direction != DIR_UP) begin next_direction <= DIR_DOWN; direction_changed <= 1'b1; end
                    8'h61, 8'h41: if (snake_direction != DIR_RIGHT) begin next_direction <= DIR_LEFT; direction_changed <= 1'b1; end
                    8'h64, 8'h44: if (snake_direction != DIR_LEFT) begin next_direction <= DIR_RIGHT; direction_changed <= 1'b1; end
                endcase
            end
            else if (btn_pressed[0] && snake_direction != DIR_DOWN) begin next_direction <= DIR_UP; direction_changed <= 1'b1; end
            else if (btn_pressed[1] && snake_direction != DIR_UP) begin next_direction <= DIR_DOWN; direction_changed <= 1'b1; end
            else if (btn_pressed[2] && snake_direction != DIR_RIGHT) begin next_direction <= DIR_LEFT; direction_changed <= 1'b1; end
            else if (btn_pressed[3] && snake_direction != DIR_LEFT) begin next_direction <= DIR_RIGHT; direction_changed <= 1'b1; end
        end
        
        if (!received) uart_data_read <= 1'b0;
        
        // Movement
        if (move_tick && !collision) begin
            direction_changed <= 1'b0;
            snake_direction <= next_direction;
            
            for (i = 0; i < OBSTACLE_NUM; i = i + 1) begin
                if (next_head_x == obstacle_pos_x[i] && next_head_y == obstacle_pos_y[i] && obstacle_valid[i]) begin
                    obstacle_valid[i] <= 1'b0; 
                end
            end

            // Move body
            for (i = SNAKE_MAX_LEN-1; i > 0; i = i - 1) begin
                if (i < snake_length) begin
                    snake_x[i] <= snake_x[i-1];
                    snake_y[i] <= snake_y[i-1];
                end
            end
            // Add length
                if(next_head_x == fruit_x && next_head_y == fruit_y) begin
                    snake_x[snake_length] = snake_x[snake_length - 1];
                    snake_y[snake_length] = snake_y[snake_length - 1];
                    snake_length <= snake_length + 1;
                end
            
            // Move head
            snake_x[0] <= next_head_x;
            snake_y[0] <= next_head_y;
        end
        else if (move_tick) begin
            direction_changed <= 1'b0;
        end
        
        
    end else begin
        direction_changed <= 1'b0;
        uart_data_read <= 1'b0;
    end
end

//========================================================================
// Boost Timer
//========================================================================
assign current_speed_limit = (boost_timer > 0) ? SPEED_FAST : SPEED_NORMAL;

always @(posedge clk) begin
    if (~reset_n || game_state == STATE_INIT) begin
        boost_timer <= 0;
    end 
    else if (game_state == STATE_PLAYING) begin
        if (lightning_eat) begin
            boost_timer <= BOOST_DURATION;
        end
        else if (boost_timer > 0) begin
            boost_timer <= boost_timer - 1;
        end
    end
end

//========================================================================
// Movement Timer
//========================================================================
always @(posedge clk) begin
    if (~reset_n || game_state != STATE_PLAYING) begin
        move_counter <= 0;
    end else begin
        if (move_counter >= current_speed_limit - 1)
            move_counter <= 0;
        else
            move_counter <= move_counter + 1;
    end
end

assign move_tick = (move_counter == current_speed_limit - 1);

//========================================================================
// Collision Detection
//========================================================================
assign pre_portal_x = (next_direction == DIR_RIGHT) ? ((snake_x[0] == GRID_W-2) ? 6'd1 : snake_x[0] + 5'd1) :
                      (next_direction == DIR_LEFT)  ? ((snake_x[0] == 6'd1)     ? (GRID_W-2) : snake_x[0] - 5'd1) : snake_x[0];

assign pre_portal_y = (next_direction == DIR_DOWN) ? (snake_y[0] + 5'd1) :
                      (next_direction == DIR_UP)   ? (snake_y[0] - 5'd1) : 
                      snake_y[0];

assign next_head_x = (pre_portal_x == portal1_x && pre_portal_y == portal1_y) ? portal2_x :
                     (pre_portal_x == portal2_x && pre_portal_y == portal2_y) ? portal1_x :
                     pre_portal_x;

assign next_head_y = (pre_portal_x == portal1_x && pre_portal_y == portal1_y) ? portal2_y :
                     (pre_portal_x == portal2_x && pre_portal_y == portal2_y) ? portal1_y :
                     pre_portal_y;

reg [1:0] count;
always @(*) begin
    self_collision_reg = 1'b0;
    count = count + 1;
    case (count)

    2'b0 :

        for (i = 1; i <= 25 ; i = i + 1) begin
            if (i < snake_length) begin
                if (snake_x[0] == snake_x[i] && snake_y[0] == snake_y[i]) begin
                    self_collision_reg = 1'b1;
                end
            end
        end

    2'b1: for (i = 26; i <=50; i = i + 1) begin
            if (i < snake_length) begin
                if (snake_x[0] == snake_x[i] && snake_y[0] == snake_y[i]) begin
                    self_collision_reg = 1'b1;
                end
            end
        end

    2'b10: for (i = 51; i <=75; i = i + 1) begin
            if (i < snake_length) begin
                if (snake_x[0] == snake_x[i] && snake_y[0] == snake_y[i]) begin
                    self_collision_reg = 1'b1;
                end
            end
        end

    2'b11: for (i = 76; i <= SNAKE_MAX_LEN; i = i + 1) begin
            if (i < snake_length) begin
                if (snake_x[0] == snake_x[i] && snake_y[0] == snake_y[i]) begin
                    self_collision_reg = 1'b1;
                end
            end
        end
endcase
end

assign self_collision = self_collision_reg;

assign wall_collision = (snake_y[0] >= GRID_H-1) || (snake_y[0] == 6'd0);

assign collision = wall_collision || self_collision;

always @(*) begin
    is_hitting_obstacle = 1'b0;
    for (i = 0; i < OBSTACLE_NUM; i = i + 1) begin
        if (next_head_x == obstacle_pos_x[i] && next_head_y == obstacle_pos_y[i]) begin
            is_hitting_obstacle = 1'b1;
        end
    end
end

//========================================================================
// Fruit Generating
//========================================================================
always @(*) begin
    fruit_vaild = 1'b1;
    for (i = 0; i < SNAKE_MAX_LEN; i = i + 1) begin
        if (i < snake_length) begin
            if (rand_x + 1 == snake_x[i] && rand_y + 1 == snake_y[i]) fruit_vaild = 1'b0;
        end
    end
    for (i = 0; i < OBSTACLE_NUM; i = i + 1) begin
        if (rand_x + 1 == obstacle_pos_x[i] && rand_y + 1 == obstacle_pos_y[i]) fruit_vaild = 1'b0;
    end
    if (lightning_on_field && (rand_x + 1 == lightning_x && rand_y + 1 == lightning_y)) fruit_vaild = 1'b0;
    
    // 檢查傳送門 (P1 & P2 都是固定且有效的)
    if ((rand_x + 1 == portal1_x && rand_y + 1 == portal1_y) || (rand_x + 1 == portal2_x && rand_y + 1 == portal2_y)) fruit_vaild = 1'b0;
end

always @(*) begin
    lightning_valid = 1'b1;
    for (i = 0; i < SNAKE_MAX_LEN; i = i + 1) begin
        if (i < snake_length) begin
            if (rand_L_x + 1 == snake_x[i] && rand_L_y + 1 == snake_y[i]) lightning_valid = 1'b0;
        end
    end
    for (i = 0; i < OBSTACLE_NUM; i = i + 1) begin
        if (rand_L_x + 1 == obstacle_pos_x[i] && rand_L_y + 1 == obstacle_pos_y[i]) lightning_valid = 1'b0;
    end
    if (fruit_on_field && (rand_L_x + 1 == fruit_x && rand_L_y + 1 == fruit_y)) lightning_valid = 1'b0;
    
    // 檢查傳送門
    if ((rand_L_x + 1 == portal1_x && rand_L_y + 1 == portal1_y) || (rand_L_x + 1 == portal2_x && rand_L_y + 1 == portal2_y)) lightning_valid = 1'b0;
end

always @(posedge clk) begin
    if(~reset_n || game_state == STATE_INIT) begin
        fruit_x <= 0;
        fruit_y <= 0;
        fruit_eat <= 0;
        fruit_on_field <= 0;
    end
    else if(game_state == STATE_PLAYING) begin
    
        if(fruit_eat) begin
            fruit_x <= 0;
            fruit_y <= 0;
            fruit_on_field <= 0;
            fruit_eat <= 0;
        end
        else begin
            if (fruit_x == snake_x[0] && fruit_y == snake_y[0] && fruit_on_field)
                fruit_eat <= 1'b1;
        end
        if(!fruit_on_field) begin
            if(fruit_vaild) begin
                fruit_x <= rand_x + 1;
                fruit_y <= rand_y + 1;
                fruit_on_field <= 1;
            end
        end

    end
end

always @(posedge clk) begin
    if(~reset_n || game_state == STATE_INIT) begin
        lightning_x <= 0; lightning_y <= 0; lightning_eat <= 0; lightning_on_field <= 0;
    end
    else if(game_state == STATE_PLAYING) begin
        // --- Lightning Logic ---
        if(lightning_eat) begin
            lightning_x <= 0; lightning_y <= 0; lightning_on_field <= 0; lightning_eat <= 0;
        end
        else begin
            if (lightning_x == snake_x[0] && lightning_y == snake_y[0] && lightning_on_field) lightning_eat <= 1'b1;
        end
        if(!lightning_on_field) begin
            if(lightning_valid) begin
                lightning_x <= rand_L_x + 1; 
                lightning_y <= rand_L_y + 1; 
                lightning_on_field <= 1;
            end
        end
    end
end
//========================================================================
// Obstacles
//========================================================================


always @(posedge clk) begin
    if(~reset_n || game_state == STATE_INIT) begin
        if (usr_sw[0] == 1'b1) begin
            obstacle_pos_x[0] <= 4;  obstacle_pos_y[0] <= 3;
            obstacle_pos_x[1] <= 11; obstacle_pos_y[1] <= 2;
            obstacle_pos_x[2] <= 5;  obstacle_pos_y[2] <= 8;
            obstacle_pos_x[3] <= 7;  obstacle_pos_y[3] <= 4;
            obstacle_pos_x[4] <= 12; obstacle_pos_y[4] <= 8;
        end
        else begin
            obstacle_pos_x[0] <= 3;  obstacle_pos_y[0] <= 3;
            obstacle_pos_x[1] <= 3;  obstacle_pos_y[1] <= 4;
            obstacle_pos_x[2] <= 3;  obstacle_pos_y[2] <= 5;
            obstacle_pos_x[3] <= 12; obstacle_pos_y[3] <= 6;
            obstacle_pos_x[4] <= 12; obstacle_pos_y[4] <= 7;
        end
    end
    else if (game_state == STATE_PLAYING && move_tick) begin
        for(i=0; i<OBSTACLE_NUM; i=i+1) begin
            if(next_head_x == obstacle_pos_x[i] && next_head_y == obstacle_pos_y[i]) begin
                // 重生 + 防重疊 (水果 & 閃電 & 傳送門)
                if ((rand_x + 1 == fruit_x && rand_y + 1 == fruit_y) || 
                    (rand_x + 1 == lightning_x && rand_y + 1 == lightning_y) ||
                    (rand_x + 1 == portal1_x && rand_y + 1 == portal1_y) ||
                    (rand_x + 1 == portal2_x && rand_y + 1 == portal2_y)) begin
                    obstacle_pos_x[i] <= (rand_x + 1 == GRID_W - 2) ? 1 : rand_x + 2; 
                    obstacle_pos_y[i] <= rand_y + 1;
                end
                else begin
                    obstacle_pos_x[i] <= rand_x + 1;
                    obstacle_pos_y[i] <= rand_y + 1;
                end
            end
        end
    end
end

//========================================================================
// Score
//========================================================================

always @(posedge clk) begin
    if(~reset_n || game_state == STATE_INIT) begin
        score <= 5;
        score_1 <= 5;
        score_10 <= 0;
    end
    else if(game_state == STATE_PLAYING) begin
        if(fruit_eat) begin
            if(score_1 == 9) begin
                score_1 <= 0;
                score_10 <= score_10 + 1;
            end
            else score_1 <= score_1 + 1;
        end
        else if(move_tick && is_hitting_obstacle) begin
            if(score_1 == 0) begin
                score_1 <= 9;
                score_10 <= score_10 - 1;
            end
            else score_1 <= score_1 - 1;
        end
        score <= score_10 * 10 + score_1;
    end
end


always @(*) begin
    if (is_score_num_10) begin
        case (score_10)
            0: score_addr_base = 18'd0000;
            1: score_addr_base = 18'd0400;
            2: score_addr_base = 18'd0800;
            3: score_addr_base = 18'd1200;
            4: score_addr_base = 18'd1600;
            5: score_addr_base = 18'd2000;
            6: score_addr_base = 18'd2400;
            7: score_addr_base = 18'd2800;
            8: score_addr_base = 18'd3200;
            9: score_addr_base = 18'd3600;
            default: score_addr_base = 18'd0000;
        endcase
    end
    
    else if (is_score_num_1) begin
        case (score_1)
            0: score_addr_base = 18'd0000;
            1: score_addr_base = 18'd0400;
            2: score_addr_base = 18'd0800;
            3: score_addr_base = 18'd1200;
            4: score_addr_base = 18'd1600;
            5: score_addr_base = 18'd2000;
            6: score_addr_base = 18'd2400;
            7: score_addr_base = 18'd2800;
            8: score_addr_base = 18'd3200;
            9: score_addr_base = 18'd3600;
            default: score_addr_base = 18'd0000;
        endcase
    end
    else begin
        score_addr_base = 18'd0000;
    end
end

//========================================================================
// VGA Rendering
//========================================================================


// Check if pixel is snake
always @(*) begin
    is_snake_reg = 1'b0;
    for (i = 0; i < SNAKE_MAX_LEN; i = i + 1) begin
        if (i < snake_length) begin
            if (current_grid_x == snake_x[i] && current_grid_y == snake_y[i]) is_snake_reg = 1'b1;
        end
    end
end

assign is_snake = is_snake_reg;
assign is_fruit = (fruit_x == current_grid_x && fruit_y == current_grid_y) && fruit_on_field;
assign is_lightning = (lightning_x == current_grid_x && lightning_y == current_grid_y) && lightning_on_field; 
assign is_score_text = (current_grid_x >= 11 && current_grid_x <= 13 && current_grid_y == 0);
assign is_score_num_10 = (current_grid_x == 14 && current_grid_y == 0);
assign is_score_num_1 = (current_grid_x == 15 && current_grid_y == 0);

// [新增] 傳送門顯示邏輯
assign is_portal1 = (current_grid_x == portal1_x && current_grid_y == portal1_y);
assign is_portal2 = (current_grid_x == portal2_x && current_grid_y == portal2_y);

assign is_obstacle = (current_grid_x == obstacle_pos_x[0] && current_grid_y == obstacle_pos_y[0]) ||
                     (current_grid_x == obstacle_pos_x[1] && current_grid_y == obstacle_pos_y[1]) ||
                     (current_grid_x == obstacle_pos_x[2] && current_grid_y == obstacle_pos_y[2]) ||
                     (current_grid_x == obstacle_pos_x[3] && current_grid_y == obstacle_pos_y[3]) ||
                     (current_grid_x == obstacle_pos_x[4] && current_grid_y == obstacle_pos_y[4]);
// Texture coordinates

wire [8:0] pix_x_half = pixel_x >> 1;
wire [7:0] pix_y_half = pixel_y >> 1;

assign current_grid_x = (pixel_x >> 1) / GRID_SIZE;  
assign current_grid_y = (pixel_y >> 1) / GRID_SIZE;  

wire [4:0] snake_tex_x = pix_x_half % GRID_SIZE; 
wire [4:0] snake_tex_y = pix_y_half % GRID_SIZE; 

wire [4:0] grid_pixel_x = pix_x_half % GRID_SIZE; 
wire [4:0] grid_pixel_y = pix_y_half % GRID_SIZE; 

wire is_skin_preview = (pix_x_half >= PREVIEW_X && pix_x_half < PREVIEW_X + SNAKE_SKIN_SIZE && pix_y_half >= PREVIEW_Y && pix_y_half < PREVIEW_Y + SNAKE_SKIN_SIZE);
wire is_skin_border_box = (pix_x_half >= PREVIEW_X - 2 && pix_x_half < PREVIEW_X + SNAKE_SKIN_SIZE + 2 && pix_y_half >= PREVIEW_Y - 2 && pix_y_half < PREVIEW_Y + SNAKE_SKIN_SIZE + 2);

assign question_addr_wire = (pix_y_half - PREVIEW_Y) * SNAKE_SKIN_SIZE + (pix_x_half - PREVIEW_X);

assign bg_addr = (pixel_y >> 1) * VBUF_W + (pixel_x >> 1);
assign skin_addr = (game_state == STATE_INIT && is_skin_preview)? (skin_addr_base + (pix_y_half - PREVIEW_Y) * SNAKE_SKIN_SIZE + (pix_x_half - PREVIEW_X)) : (skin_addr_base + snake_tex_y * SNAKE_SKIN_SIZE + snake_tex_x);
assign fruit_addr = grid_pixel_y * FRUIT_SIZE + grid_pixel_x;
assign lightning_addr = grid_pixel_y * GRID_SIZE + grid_pixel_x;
assign portal_addr = grid_pixel_y * GRID_SIZE + grid_pixel_x; // [新增]

wire [5:0] score_x_offset = (current_grid_x >= 11 && current_grid_x <= 13) ? 
                            (current_grid_x - 6'd11) : 6'd0;

assign score_text_addr = (18'd0 + grid_pixel_y) * 18'd60 + 
                         (18'd0 + grid_pixel_x) + 
                         (18'd0 + score_x_offset) * 18'd20;



assign score_num_addr = grid_pixel_y * GRID_SIZE + grid_pixel_x + score_addr_base;

                                    
assign obstacle_addr = grid_pixel_y * GRID_SIZE + grid_pixel_x;

assign {VGA_RED, VGA_GREEN, VGA_BLUE} = rgb_reg;

wire is_start_area = (pix_x_half >= 26 && pix_x_half < 293 && pix_y_half >= 40 && pix_y_half < 89);

wire [8:0] start_x_offset = (pix_x_half >= 26) ? (pix_x_half - 9'd26) : 9'd0;
wire [7:0] start_y_offset = (pix_y_half >= 40) ? (pix_y_half - 8'd40) : 8'd0;

assign start_addr = (18'd0 + start_y_offset) * 18'd267 + (18'd0 + start_x_offset);

//Map 1 
wire is_map1_area = (pix_x_half >= 64 && pix_x_half < 136 && pix_y_half >= 140 && pix_y_half < 178);
assign map1_img_addr = (pix_y_half - 140) * MAP_ICON_W + (pix_x_half - 64);

// Map 2 
wire is_map2_area = (pix_x_half >= 184 && pix_x_half < 256 && pix_y_half >= 140 && pix_y_half < 178);
assign map2_img_addr = (pix_y_half - 140) * MAP_ICON_W + (pix_x_half - 184);

// 白色選取邊框
wire is_border_1 = (pix_x_half >= 62 && pix_x_half < 138 && pix_y_half >= 138 && pix_y_half < 180);
wire is_border_2 = (pix_x_half >= 182 && pix_x_half < 258 && pix_y_half >= 138 && pix_y_half < 180);

//Game Over 
wire is_over_area = (pix_x_half >= 37 && pix_x_half < 283 && pix_y_half >= 100 && pix_y_half < 128);
assign over_addr = (pix_y_half - 100) * OVER_W + (pix_x_half - 37);

wire is_choose_area = (pix_x_half >= 5 && pix_x_half < 188 &&
                        pix_y_half >= 210 && pix_y_half < 231);

wire [8:0] choose_x_offset = (pix_x_half >= 5) ? (pix_x_half - 9'd5) : 9'd0;
wire [7:0] choose_y_offset = (pix_y_half >= 210) ? (pix_y_half - 8'd210) : 8'd0;

assign choose_addr = (18'd0 + choose_y_offset) * 18'd183 + (18'd0 + choose_x_offset);

wire is_snake_eye =  (next_direction == DIR_UP &&(( grid_pixel_x >= 6 && grid_pixel_x <= 7 ) || ( grid_pixel_x >= 12 && grid_pixel_x <= 13 ))&& grid_pixel_y >= 4 && grid_pixel_y <= 6) ||
                     (next_direction == DIR_LEFT &&(( grid_pixel_y >= 6 && grid_pixel_y <= 7 ) || ( grid_pixel_y >= 12 && grid_pixel_y <= 13 ))&& grid_pixel_x >= 4 && grid_pixel_x <= 6) ||
                     (next_direction == DIR_RIGHT &&(( grid_pixel_y >= 6 && grid_pixel_y <= 7 ) || ( grid_pixel_y >= 12 && grid_pixel_y <= 13 ))&& grid_pixel_x >= 13 && grid_pixel_x <= 15) ||
                     (next_direction == DIR_DOWN &&(( grid_pixel_x >= 6 && grid_pixel_x <= 7 ) || ( grid_pixel_x >= 12 && grid_pixel_x <= 13 ))&& grid_pixel_y >= 13 && grid_pixel_y <= 15);   


always @(posedge clk) begin
    if (pixel_tick) rgb_reg <= rgb_next;
end

always @(posedge clk) begin
    if (~video_on) begin
        rgb_next <= 12'h000;
    end 
    else begin
        // ============================================================
        // 狀態 1: 初始選單畫面 
        // ============================================================
        if (game_state == STATE_INIT) begin
            if (is_start_area && start_data != 12'h0f0) rgb_next <= start_data;
            else if (is_map1_area && map1_img_data != 12'h0f0) rgb_next <= map1_img_data;
            else if (is_map2_area && map2_img_data != 12'h0f0) rgb_next <= map2_img_data;
            else if (is_choose_area && choose_data != 12'h0f0) rgb_next <= choose_data;
            else if (usr_sw[0] == 1'b0 && is_border_1 && !is_map1_area) rgb_next <= 12'hFFF; 
            else if (usr_sw[0] == 1'b1 && is_border_2 && !is_map2_area) rgb_next <= 12'hFFF;
            else if (is_skin_preview) begin
                if (is_random_skin_mode) rgb_next <= question_data;
                else rgb_next <= skin_data;
            end
            else if (is_skin_border_box) rgb_next <= 12'hFFF;   
            else rgb_next <= 12'h003; 
        end
        
        // ============================================================
        // 狀態 2: 遊戲結束畫面
        // ============================================================
        else if (game_state == STATE_GAMEOVER) begin
            if (is_over_area && over_data != 12'h0f0) rgb_next <= over_data;
            else rgb_next <= 12'h300; 
        end
        else begin
            if (is_score_text && score_text_data != 12'h0f0) rgb_next <= score_text_data;
            else if ((is_score_num_1 || is_score_num_10) && score_num_data != 12'h0f0) rgb_next <= score_num_data;
            else if (current_grid_y == 0 || current_grid_y == GRID_H-1) rgb_next <= 12'h684;
            else if (current_grid_x == 0 || current_grid_x == GRID_W-1) rgb_next <= 12'h799;
            else if (is_snake) begin
                if(current_grid_x == snake_x[0] && current_grid_y == snake_y[0]) begin
                    if(is_snake_eye) rgb_next <= 12'hfff;
                    else rgb_next <= skin_data;
                end
                else rgb_next <= skin_data;
            end            
            // 渲染順序：傳送門 -> 閃電 -> 水果
            else if ((is_portal1 || is_portal2) && portal_data != 12'h0f0) rgb_next <= portal_data; // [新增]
            else if (is_lightning && lightning_data != 12'h0f0) rgb_next <= lightning_data;
            else if (is_fruit && fruit_data != 12'h0f0) rgb_next <= fruit_data;
            
            else if (is_obstacle) begin
                if(obstacle_data == 12'h0f0) rgb_next <= 12'h000;
                else rgb_next <= obstacle_data;
            end
            else begin
                rgb_next <= ((current_grid_x + current_grid_y) & 1'b1) ? 12'h8a5 : 12'h9c6;
            end
        end
    end
end

//========================================================================
// LCD Module
//========================================================================
LCD_module lcd0(
    .clk(clk),
    .reset(~reset_n),
    .row_A(row_A),
    .row_B(row_B),
    .LCD_E(LCD_E),
    .LCD_RS(LCD_RS),
    .LCD_RW(LCD_RW),
    .LCD_D(LCD_D)
);

//========================================================================
// LCD Display Logic
//========================================================================
reg [7:0] head_x_tens, head_x_ones;
reg [7:0] head_y_tens, head_y_ones;
reg [7:0] len_tens, len_ones;

//always @(posedge clk) begin
//    if (~reset_n) begin
//        row_A <= "reseting        ";
//        row_B <= "loading         ";
//    end
//    else begin
//        head_x_tens = 8'd48 + (snake_x[0] / 10);
//        head_x_ones = 8'd48 + (snake_x[0] % 10);
//        head_y_tens = 8'd48 + (snake_y[0] / 10);
//        head_y_ones = 8'd48 + (snake_y[0] % 10);
//        len_tens = 8'd48 + (snake_length / 10);
//        len_ones = 8'd48 + (snake_length % 10);
        
//        row_A = {"Head:[", 
//                 head_x_tens, head_x_ones, ",",
//                 head_y_tens, head_y_ones,
//                 "]     "};
        
//        case (game_state)
//            STATE_INIT: 
//                row_B = {"ST:I ", collision ? "C:Y" : "C:N", " Len:", len_tens, len_ones, " "};
//            STATE_PLAYING:
//                row_B = {"ST:P ", collision ? "C:Y" : "C:N", " Len:", len_tens, len_ones, " "};
//            STATE_GAMEOVER:
//                row_B = {"ST:G ", collision ? "C:Y" : "C:N", " Len:", len_tens, len_ones, " "};
//            default:
//                row_B = {"ST:? C:? Len:?? "};
//        endcase
//    end
//end

always @(*) begin
    row_A = "Snake Game Test ";
    row_B = "LCD Working?    ";
end


endmodule