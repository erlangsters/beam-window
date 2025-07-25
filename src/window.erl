%%
%% Copyright (c) 2025, Byteplug LLC.
%%
%% This source file is part of a project made by the Erlangsters community and
%% is released under the MIT license. Please refer to the LICENSE.md file that
%% can be found at the root of the project repository.
%%
%% Written by Jonathan De Wachter <jonathan.dewachter@byteplug.io>
%%
-module(window).
-moduledoc """
To be written.

To be written.
""".

-export([run/5]).

-include_lib("glfw/include/glfw.hrl").

-type glfw_event() ::
    #glfw_window_position{} |
    #glfw_window_size{} |
    #glfw_window_close{} |
    #glfw_window_refresh{} |
    #glfw_window_focus{} |
    #glfw_window_iconify{} |
    #glfw_window_maximize{} |
    #glfw_window_content_scale{} |
    #glfw_key{} |
    #glfw_char{} |
    #glfw_char_mods{} |
    #glfw_mouse_button{} |
    #glfw_cursor_position{} |
    #glfw_cursor_enter{} |
    #glfw_scroll{} |
    #glfw_drop{}
.

-type action() :: do_nothing.  % No action for now.

-callback initialize(Args :: [term()]) ->
    {continue, State :: term()} |
    {continue, State :: term(), Actions :: [action()]} |
    {abort, Reason :: term()}
.

-callback handle_event(
    Window :: glfw:window(),
    Event :: glfw_event(),
    State :: term()
) ->
    {continue, NewState :: term()} |
    {continue, NewState :: term(), Action :: action()} |
    {stop, Reason :: term(), State :: term()}
.

-callback handle_render(
    Window :: glfw:window(),
    State :: term()
) ->
    {continue, NewState :: term()} |
    {continue, NewState :: term(), Action :: action()} |
    {stop, Reason :: term(), State :: term()}
.

-callback handle_message(
    Window :: glfw:window(),
    Message :: term(),
    State :: term()
) ->
    {continue, NewState :: term()} |
    {continue, NewState :: term(), Action :: action()} |
    {stop, Reason :: term(), State :: term()}
.

-callback terminate(
    Window :: glfw:window(),
    Reason :: term(),
    State :: term())
-> Return :: term().

-doc """
To be written.

To be written.
""".
run(Width, Height, Title, Module, Args) ->
    glfw_debug:setup_handler(),
    true = glfw:init(),

    case glfw:create_window(Width, Height, Title) of
        no_window ->
            {error, cannot_create_window};
        {ok, Window} ->
            case Module:initialize(Window, Args) of
                {continue, State} ->
                    do_loop(Window, Module, State, []);
                {continue, State, Actions} ->
                    do_loop(Window, Module, State, Actions);
                {abort, Reason} ->
                    {error, {initialization_aborted, Reason}}
            end
    end.

do_loop(Window, Module, State, Actions) ->
    ok = glfw:set_window_size_handler(Window, self()),
    ok = glfw:set_window_close_handler(Window, self()),
    ok = glfw:set_key_handler(Window, self()),

    ok = loop(Window, Module, State, Actions),

    glfw:destroy_window(Window),
    glfw:terminate(),

    ok.

loop(Window, Module, State, []) ->
    case glfw:window_should_close(Window) of
        true ->
            io:format("[debug] window should close~n"),
            ok;
        false ->
            glfw:poll_events(),
            case do_handle_event(Window, Module, State) of
                {continue, NewState1} ->
                    case Module:handle_render(Window, NewState1) of
                        {continue, NewState2} ->
                            loop(Window, Module, NewState2, []);
                        {continue, NewState2, Actions} ->
                            loop(Window, Module, NewState2, Actions);
                        {stop, Reason, NewState2} ->
                            Module:terminate(Window, Reason, NewState2),
                            ok
                    end;
                {stop, Reason, NewState} ->
                    Module:terminate(Window, Reason, NewState),
                    ok
            end
    end.

do_handle_event(Window, Module, State) ->
    case handle_event(Window) of
        {event_message, Event} ->
            Result = Module:handle_event(Window, Event, State),
            case Result of
                {continue, NewState} ->
                    do_handle_event(Window, Module, NewState);
                {continue, NewState, _Actions} ->
                    do_handle_event(Window, Module, NewState);
                {stop, Reason, NewState} ->
                    {stop, Reason, NewState}
            end;
        {no_event_message, Message} ->
            case Module:handle_message(Window, Message, State) of
                {continue, NewState} ->
                    do_handle_event(Window, Module, NewState);
                {continue, NewState, _Actions} ->
                    do_handle_event(Window, Module, NewState);
                {stop, Reason, NewState} ->
                    {stop, Reason, NewState}
            end;
        no_message ->
            {continue, State}
    end.

handle_event(Window) ->
    receive
        #glfw_window_position{window=Window} = Event ->
            {event_message, Event};
        #glfw_window_size{window=Window} = Event ->
            {event_message, Event};
        #glfw_window_close{window=Window} = Event ->
            {event_message, Event};
        #glfw_window_refresh{window=Window} = Event ->
            {event_message, Event};
        #glfw_window_focus{window=Window} = Event ->
            {event_message, Event};
        #glfw_window_iconify{window=Window} = Event ->
            {event_message, Event};
        #glfw_window_maximize{window=Window} = Event ->
            {event_message, Event};
        #glfw_window_content_scale{window=Window} = Event ->
            {event_message, Event};
        #glfw_key{window=Window, key=Value} = Event ->
            % XXX: Remove this fix after it's fixed in the GLFw binding.
            Atom = key_value_to_atom(Value),
            FixedEvent = Event#glfw_key{key=Atom},
            {event_message, FixedEvent};
        #glfw_char{window=Window} = Event ->
            {event_message, Event};
        #glfw_char_mods{window=Window} = Event ->
            {event_message, Event};
        #glfw_cursor_position{window=Window} = Event ->
            {event_message, Event};
        #glfw_scroll{window=Window} = Event ->
            {event_message, Event};
        #glfw_drop{window=Window} = Event ->
            {event_message, Event};
        Message ->
            {no_event_message, Message}
    after 0 ->
        no_message
    end.

key_value_to_atom(Value) ->
    case Value of
        32 -> key_space;
        39 -> key_apostrophe;
        44 -> key_comma;
        45 -> key_minus;
        46 -> key_period;
        47 -> key_slash;
        48 -> key_0;
        49 -> key_1;
        50 -> key_2;
        51 -> key_3;
        52 -> key_4;
        53 -> key_5;
        54 -> key_6;
        55 -> key_7;
        56 -> key_8;
        57 -> key_9;
        59 -> key_semicolon;
        61 -> key_equal;
        65 -> key_a;
        66 -> key_b;
        67 -> key_c;
        68 -> key_d;
        69 -> key_e;
        70 -> key_f;
        71 -> key_g;
        72 -> key_h;
        73 -> key_i;
        74 -> key_j;
        75 -> key_k;
        76 -> key_l;
        77 -> key_m;
        78 -> key_n;
        79 -> key_o;
        80 -> key_p;
        81 -> key_q;
        82 -> key_r;
        83 -> key_s;
        84 -> key_t;
        85 -> key_u;
        86 -> key_v;
        87 -> key_w;
        88 -> key_x;
        89 -> key_y;
        90 -> key_z;
        91 -> key_left_bracket;
        92 -> key_backslash;
        93 -> key_right_bracket;
        96 -> key_grave_accent;
        161 -> key_world_1;
        162 -> key_world_2;
        256 -> key_escape;
        257 -> key_enter;
        258 -> key_tab;
        259 -> key_backspace;
        260 -> key_insert;
        261 -> key_delete;
        262 -> key_right;
        263 -> key_left;
        264 -> key_down;
        265 -> key_up;
        266 -> key_page_up;
        267 -> key_page_down;
        268 -> key_home;
        269 -> key_end;
        280 -> key_caps_lock;
        281 -> key_scroll_lock;
        282 -> key_num_lock;
        283 -> key_print_screen;
        284 -> key_pause;
        290 -> key_f1;
        291 -> key_f2;
        292 -> key_f3;
        293 -> key_f4;
        294 -> key_f5;
        295 -> key_f6;
        296 -> key_f7;
        297 -> key_f8;
        298 -> key_f9;
        299 -> key_f10;
        300 -> key_f11;
        301 -> key_f12;
        302 -> key_f13;
        303 -> key_f14;
        304 -> key_f15;
        305 -> key_f16;
        306 -> key_f17;
        307 -> key_f18;
        308 -> key_f19;
        309 -> key_f20;
        310 -> key_f21;
        311 -> key_f22;
        312 -> key_f23;
        313 -> key_f24;
        314 -> key_f25;
        320 -> key_kp_0;
        321 -> key_kp_1;
        322 -> key_kp_2;
        323 -> key_kp_3;
        324 -> key_kp_4;
        325 -> key_kp_5;
        326 -> key_kp_6;
        327 -> key_kp_7;
        328 -> key_kp_8;
        329 -> key_kp_9;
        330 -> key_kp_decimal;
        331 -> key_kp_divide;
        332 -> key_kp_multiply;
        333 -> key_kp_subtract;
        334 -> key_kp_add;
        335 -> key_kp_enter;
        336 -> key_kp_equal;
        340 -> key_left_shift;
        341 -> key_left_control;
        342 -> key_left_alt;
        343 -> key_left_super;
        344 -> key_right_shift;
        345 -> key_right_control;
        346 -> key_right_alt;
        347 -> key_right_super;
        348 -> key_menu
    end.
