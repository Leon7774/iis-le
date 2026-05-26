#include <avr/pgmspace.h>

// PIN CONFIGURATION (Explicitly using const uint8_t for compiler optimization)
const uint8_t PIN_MOTOR_ENA = 5;
const uint8_t PIN_MOTOR_IN1 = 6;
const uint8_t PIN_MOTOR_IN2 = 7;
const uint8_t PIN_MOTOR_IN3 = 8;
const uint8_t PIN_MOTOR_IN4 = 9;
const uint8_t PIN_MOTOR_ENB = 10;

const uint8_t PIN_SENS_L_OUT = A4;  
const uint8_t PIN_SENS_L_IN  = A2;
const uint8_t PIN_SENS_MID   = A1;
const uint8_t PIN_SENS_R_IN  = A0;
const uint8_t PIN_SENS_R_OUT = A3;  

// SYSTEM CONSTANTS (Increased BASE_SPEED from 110 to 150 to prevent motor stalling)
#define SENSOR_THRESHOLD     600  
#define BASE_SPEED           150    
#define TURN_SPEED           180  
#define MIN_NODE_INTERVAL_MS 1000 

// CONFIGURATION
#define START_NODE 17
#define END_NODE 23
#define INITIAL_HEADING 6

// GRAPH ARCHITECTURE
#define MAX_NODES 50
#define DIRECTIONS_PER_NODE 8

enum NodeType : uint8_t {
    NODE_TYPE_BLACK_LINE = 0,
    NODE_TYPE_WHITE_MARKER = 1
};

struct NodeAttributes {
    uint8_t type; 
};

// Symmetrical track configuration: 21, 22, 26, 27 are white markers
const NodeAttributes NODE_CONFIG[MAX_NODES] PROGMEM = {
    {NODE_TYPE_BLACK_LINE}, {NODE_TYPE_BLACK_LINE}, {NODE_TYPE_BLACK_LINE}, {NODE_TYPE_BLACK_LINE}, {NODE_TYPE_BLACK_LINE}, // 0-4
    {NODE_TYPE_BLACK_LINE}, {NODE_TYPE_BLACK_LINE}, {NODE_TYPE_BLACK_LINE}, {NODE_TYPE_BLACK_LINE}, {NODE_TYPE_BLACK_LINE}, // 5-9
    {NODE_TYPE_BLACK_LINE}, {NODE_TYPE_BLACK_LINE}, {NODE_TYPE_BLACK_LINE}, {NODE_TYPE_BLACK_LINE}, {NODE_TYPE_BLACK_LINE}, // 10-14
    {NODE_TYPE_BLACK_LINE}, {NODE_TYPE_BLACK_LINE}, {NODE_TYPE_BLACK_LINE}, {NODE_TYPE_BLACK_LINE}, {NODE_TYPE_BLACK_LINE}, // 15-19
    {NODE_TYPE_BLACK_LINE}, {NODE_TYPE_WHITE_MARKER}, {NODE_TYPE_WHITE_MARKER}, {NODE_TYPE_BLACK_LINE}, {NODE_TYPE_BLACK_LINE}, // 20-24
    {NODE_TYPE_BLACK_LINE}, {NODE_TYPE_WHITE_MARKER}, {NODE_TYPE_WHITE_MARKER}, {NODE_TYPE_BLACK_LINE}, {NODE_TYPE_BLACK_LINE}, // 25-29
    {NODE_TYPE_BLACK_LINE}, {NODE_TYPE_BLACK_LINE}, {NODE_TYPE_BLACK_LINE}, {NODE_TYPE_BLACK_LINE}, {NODE_TYPE_BLACK_LINE}, // 30-34
    {NODE_TYPE_BLACK_LINE}, {NODE_TYPE_BLACK_LINE}, {NODE_TYPE_BLACK_LINE}, {NODE_TYPE_BLACK_LINE}, {NODE_TYPE_BLACK_LINE}, // 35-39
    {NODE_TYPE_BLACK_LINE}, {NODE_TYPE_BLACK_LINE}, {NODE_TYPE_BLACK_LINE}, {NODE_TYPE_BLACK_LINE}, {NODE_TYPE_BLACK_LINE}, // 40-44
    {NODE_TYPE_BLACK_LINE}, {NODE_TYPE_BLACK_LINE}, {NODE_TYPE_BLACK_LINE}, {NODE_TYPE_BLACK_LINE}, {NODE_TYPE_BLACK_LINE}  // 45-49
};

// Full GRAPH adjacency matrix
const int GRAPH[MAX_NODES][DIRECTIONS_PER_NODE] PROGMEM = {
    {0,0,0,0,0,0,0,0}, {0,0,2,0,7,0,0,0}, {0,0,3,0,8,0,1,0}, {0,0,0,0,9,0,2,0}, {0,0,0,6,0,5,0,0}, 
    {0,4,0,11,0,10,0,0}, {0,0,0,12,0,11,0,4}, {1,0,8,0,15,0,0,0}, {2,0,9,0,16,0,7,0}, {3,0,10,0,17,0,8,0}, 
    {0,5,0,13,0,0,9,0}, {0,6,0,14,0,13,0,5}, {0,0,0,0,0,14,0,6}, {0,11,0,18,0,0,0,10}, {0,12,0,0,0,18,0,11}, 
    {7,0,16,0,0,0,0,0}, {8,0,17,0,19,0,15,0}, {9,0,0,0,0,0,16,0}, {0,14,0,0,20,0,0,13}, {16,0,20,0,23,0,21,0}, 
    {18,0,22,0,25,0,19,0}, {0,19,0,26,0,0,0,0}, {0,0,0,0,0,27,0,20}, {19,0,24,0,28,0,0,0}, {0,0,25,0,0,0,23,0}, 
    {20,0,0,0,29,0,24,0}, {0,0,0,28,0,0,0,21}, {0,22,0,0,0,29,0,0}, {23,0,29,0,30,0,26,0}, {25,0,27,0,32,0,28,0}, 
    {28,0,36,0,35,0,34,0}, {0,0,32,0,37,0,0,0}, {29,0,33,0,38,0,31,0}, {0,0,0,0,39,0,32,0}, {30,0,35,0,40,0,0,0}, 
    {30,0,36,0,40,0,34,0}, {30,0,37,0,40,0,35,0}, {31,0,38,0,41,0,36,0}, {32,0,39,0,42,0,37,0}, {33,0,0,0,43,0,38,0}, 
    {35,0,36,0,0,0,34,0}, {37,0,42,0,0,0,0,0}, {38,0,43,0,0,0,41,0}, {39,0,0,0,0,0,42,0}
};

// RUNTIME STATE
int8_t  g_current_node   = START_NODE;
int8_t  g_current_heading = INITIAL_HEADING;
uint32_t g_last_node_time_ms = 0;
uint8_t  g_junction_debounce_counter = 0;
uint8_t  g_white_debounce_counter = 0;
bool     g_line_acquired = false;

int8_t  g_planned_path[MAX_NODES];
uint8_t g_path_length = 0;
uint8_t g_path_index = 0;

// MOTOR HARDWARE INTERFACE LAYER
void set_motor_velocities(int16_t left_speed, int16_t right_speed) {
    digitalWrite(PIN_MOTOR_IN1, left_speed >= 0 ? LOW : HIGH);
    digitalWrite(PIN_MOTOR_IN2, left_speed >= 0 ? HIGH : LOW);
    digitalWrite(PIN_MOTOR_IN3, right_speed >= 0 ? LOW : HIGH);
    digitalWrite(PIN_MOTOR_IN4, right_speed >= 0 ? HIGH : LOW);
    analogWrite(PIN_MOTOR_ENA, constrain(abs(left_speed), 0, 255));
    analogWrite(PIN_MOTOR_ENB, constrain(abs(right_speed), 0, 255));
}

// BREADTH-FIRST SEARCH WITH MEMORY SAFE BOUNDS CHECKING
bool compute_shortest_path(int8_t start_node, int8_t target_node) {
    int8_t parent_registry[MAX_NODES];
    int8_t traversal_queue[MAX_NODES];
    
    memset(parent_registry, -1, sizeof(parent_registry));
    
    uint8_t queue_head = 0;
    uint8_t queue_tail = 0;
    
    traversal_queue[queue_tail++] = start_node;
    parent_registry[start_node] = start_node;
    
    while (queue_head < queue_tail) {
        int8_t current = traversal_queue[queue_head++];
        if (current == target_node) break;
        
        for (uint8_t d = 0; d < DIRECTIONS_PER_NODE; d++) {
            int8_t neighbor = (int8_t)pgm_read_word(&GRAPH[current][d]);
            if (neighbor > 0 && parent_registry[neighbor] == -1) {
                if (queue_tail >= MAX_NODES) return false; 
                
                parent_registry[neighbor] = current;
                traversal_queue[queue_tail++] = neighbor;
            }
        }
    }
    
    if (parent_registry[target_node] == -1) return false;
    
    int8_t trace_node = target_node;
    int8_t reverse_path_buffer[MAX_NODES];
    uint8_t step_counter = 0;
    
    while (trace_node != start_node) {
        reverse_path_buffer[step_counter++] = trace_node;
        trace_node = parent_registry[trace_node];
    }
    reverse_path_buffer[step_counter++] = start_node;
    
    g_path_length = step_counter;
    for (uint8_t i = 0; i < step_counter; i++) {
        g_planned_path[i] = reverse_path_buffer[step_counter - 1 - i];
    }
    return true;
}

void execute_system_halt() {
    set_motor_velocities(0, 0);
    while (true) {
    }
}

void process_node_transition(NodeType type) {
    set_motor_velocities(0, 0);
    g_path_index++;
    g_current_node = g_planned_path[g_path_index];

    if (g_current_node == g_planned_path[g_path_length - 1]) {
        execute_system_halt();
    }

    int8_t next_node = g_planned_path[g_path_index + 1];
    int16_t target_direction = -1;
    
    for (uint8_t d = 0; d < DIRECTIONS_PER_NODE; d++) {
        if ((int8_t)pgm_read_word(&GRAPH[g_current_node][d]) == next_node) {
            target_direction = d;
            break;
        }
    }

    if (target_direction == -1) execute_system_halt();

    if (type == NODE_TYPE_BLACK_LINE) {
        int16_t rotation_delta = (target_direction - g_current_heading + 8) % 8;
        if (rotation_delta != 0) {
            int8_t direction_coefficient = (rotation_delta > 4) ? -1 : 1;
            set_motor_velocities(TURN_SPEED * direction_coefficient, -TURN_SPEED * direction_coefficient);
            
            delay(300); 
            while (analogRead(PIN_SENS_MID) > SENSOR_THRESHOLD); 
            while (analogRead(PIN_SENS_MID) < SENSOR_THRESHOLD); 
            set_motor_velocities(0, 0);
        }
    }

    g_current_heading = target_direction;
    g_last_node_time_ms = millis();
    g_junction_debounce_counter = 0;
    g_white_debounce_counter = 0;
}

void setup() {
    pinMode(PIN_MOTOR_ENA, OUTPUT); pinMode(PIN_MOTOR_IN1, OUTPUT); pinMode(PIN_MOTOR_IN2, OUTPUT);
    pinMode(PIN_MOTOR_IN3, OUTPUT); pinMode(PIN_MOTOR_IN4, OUTPUT); pinMode(PIN_MOTOR_ENB, OUTPUT);
    
    if (!compute_shortest_path(g_current_node, END_NODE)) {
        execute_system_halt(); 
    }
    g_last_node_time_ms = millis(); 
}

void loop() {
    bool raw_l_out = analogRead(PIN_SENS_L_OUT) > SENSOR_THRESHOLD;
    bool raw_l_in  = analogRead(PIN_SENS_L_IN)  > SENSOR_THRESHOLD;
    bool raw_mid   = analogRead(PIN_SENS_MID)   > SENSOR_THRESHOLD;
    bool raw_r_in  = analogRead(PIN_SENS_R_IN)  > SENSOR_THRESHOLD;
    bool raw_r_out = analogRead(PIN_SENS_R_OUT) > SENSOR_THRESHOLD;

    if (!g_line_acquired) {
        if (raw_l_out || raw_l_in || raw_mid || raw_r_in || raw_r_out) g_line_acquired = true;
        else { set_motor_velocities(BASE_SPEED, BASE_SPEED); return; }
    }

    int8_t next_expected_node = (g_path_index < g_path_length - 1) ? g_planned_path[g_path_index + 1] : -1;
    
    NodeType expected_node_type = NODE_TYPE_BLACK_LINE;
    if (next_expected_node >= 0 && next_expected_node < MAX_NODES) {
        expected_node_type = (NodeType)pgm_read_byte(&NODE_CONFIG[next_expected_node].type);
    }

    if (expected_node_type == NODE_TYPE_WHITE_MARKER) {
        if (!raw_l_out && !raw_l_in && !raw_mid && !raw_r_in && !raw_r_out) {
            if (millis() - g_last_node_time_ms > MIN_NODE_INTERVAL_MS) {
                if (++g_white_debounce_counter > 6) process_node_transition(NODE_TYPE_WHITE_MARKER);
            }
        } else {
            g_white_debounce_counter = 0;
        }
    } else {
        if ((raw_l_out && raw_r_out) || (raw_l_out && raw_l_in && raw_r_in) || (raw_r_out && raw_r_in && raw_l_in)) {
            if (millis() - g_last_node_time_ms > MIN_NODE_INTERVAL_MS) {
                if (++g_junction_debounce_counter > 5) process_node_transition(NODE_TYPE_BLACK_LINE);
            }
        } else {
            g_junction_debounce_counter = 0;
        }
    }

    // LINE EXECUTOR MOTIONS
    if (g_junction_debounce_counter == 0 && g_white_debounce_counter == 0) {
        if (raw_mid) {
            if (raw_l_in && !raw_r_in)       set_motor_velocities(BASE_SPEED * 0.4, BASE_SPEED);
            else if (raw_r_in && !raw_l_in)  set_motor_velocities(BASE_SPEED, BASE_SPEED * 0.4);
            else                             set_motor_velocities(BASE_SPEED, BASE_SPEED);
        } 
        else if (raw_l_in)  set_motor_velocities(BASE_SPEED * 0.2, BASE_SPEED);
        else if (raw_r_in)  set_motor_velocities(BASE_SPEED, BASE_SPEED * 0.2);
        else if (raw_l_out) set_motor_velocities(-TURN_SPEED, TURN_SPEED);
        else if (raw_r_out) set_motor_velocities(TURN_SPEED, -TURN_SPEED);
        else                set_motor_velocities(TURN_SPEED, -TURN_SPEED);
    }
}
