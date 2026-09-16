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

-export([
    run/5,
    egl_display/0
]).

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
    #glfw_framebuffer_size{} |
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

-callback initialize(Window :: glfw:window(), Args :: [term()]) ->
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
EGL display for the current GLFW platform.

GLFW must already be initialized. On Wayland and X11 this wraps GLFW's
window-system connection through `egl:get_platform_display/3`. Call it from
`initialize/2` after `run/5` has created the window.
""".
-spec egl_display() -> egl:display() | no_display.
egl_display() ->
    case glfw:platform() of
        {ok, Platform} ->
            case {egl_platform(Platform), glfw:display_egl_handle()} of
                {undefined, _} ->
                    no_display;
                {_, error} ->
                    no_display;
                {EglPlatform, NativeDisplay} ->
                    egl:get_platform_display(EglPlatform, NativeDisplay, [])
            end;
        error ->
            no_display
    end.

egl_platform(wayland) -> wayland;
egl_platform(x11) -> x11;
egl_platform(win32) -> angle;
egl_platform(cocoa) -> angle;
egl_platform(_) -> undefined.

-doc """
To be written.

To be written.
""".
run(Width, Height, Title, Module, Args) ->
    true = glfw:init(),

    glfw:window_hint(resizable, true),
    glfw:window_hint(scale_framebuffer, true),

    case glfw:create_window(Width, Height, Title) of
        no_window ->
            glfw:terminate(),
            {error, cannot_create_window};
        {ok, Window} ->
            case Module:initialize(Window, Args) of
                {continue, State} ->
                    do_loop(Window, Module, State);
                {continue, State, _Actions} ->
                    do_loop(Window, Module, State);
                {abort, Reason} ->
                    glfw:destroy_window(Window),
                    glfw:terminate(),
                    {error, {initialization_aborted, Reason}}
            end
    end.

do_loop(Window, Module, State) ->
    ok = glfw:set_window_size_handler(Window, self()),
    ok = glfw:set_framebuffer_size_handler(Window, self()),
    ok = glfw:set_window_close_handler(Window, self()),
    ok = glfw:set_key_handler(Window, self()),
    ok = glfw:set_char_handler(Window, self()),
    ok = glfw:set_mouse_button_handler(Window, self()),
    ok = glfw:set_cursor_position_handler(Window, self()),
    ok = glfw:set_cursor_enter_handler(Window, self()),
    ok = glfw:set_scroll_handler(Window, self()),

    ok = loop(Window, Module, State),

    glfw:destroy_window(Window),
    glfw:terminate(),
    ok.

loop(Window, Module, State) ->
    case glfw:window_should_close(Window) of
        true ->
            Module:terminate(Window, window_closed, State),
            ok;
        false ->
            glfw:poll_events(),
            case do_handle_event(Window, Module, State) of
                {continue, NewState1} ->
                    case Module:handle_render(Window, NewState1) of
                        {continue, NewState2} ->
                            loop(Window, Module, NewState2);
                        {continue, NewState2, _Actions} ->
                            loop(Window, Module, NewState2);
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

handle_event(_Window) ->
    receive
        #glfw_window_position{} = Event ->
            {event_message, Event};
        #glfw_window_size{} = Event ->
            {event_message, Event};
        #glfw_window_close{} = Event ->
            {event_message, Event};
        #glfw_window_refresh{} = Event ->
            {event_message, Event};
        #glfw_window_focus{} = Event ->
            {event_message, Event};
        #glfw_window_iconify{} = Event ->
            {event_message, Event};
        #glfw_window_maximize{} = Event ->
            {event_message, Event};
        #glfw_window_content_scale{} = Event ->
            {event_message, Event};
        #glfw_framebuffer_size{} = Event ->
            {event_message, Event};
        #glfw_key{} = Event ->
            {event_message, Event};
        #glfw_char{} = Event ->
            {event_message, Event};
        #glfw_char_mods{} = Event ->
            {event_message, Event};
        #glfw_mouse_button{} = Event ->
            {event_message, Event};
        #glfw_cursor_position{} = Event ->
            {event_message, Event};
        #glfw_cursor_enter{} = Event ->
            {event_message, Event};
        #glfw_scroll{} = Event ->
            {event_message, Event};
        #glfw_drop{} = Event ->
            {event_message, Event};
        Message ->
            {no_event_message, Message}
    after 0 ->
        no_message
    end.
