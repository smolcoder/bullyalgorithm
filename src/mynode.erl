-module(mynode).

%% API

-define(ELECTION, election).
-define(ALIVE, alive).
-define(COORDINATOR, coordinator).
-define(WAIT_TIME, 50).

-record(state, {nodes=[], waiting_time=infinity, coordinator = node()}).


-export([start/1, loop/1]).

start(Nodes) ->
  register(?MODULE, self()),
  io:format("start node ~p ~p~n", [node(), os:getpid()]),
  loop(start_election(#state{nodes = Nodes})).


loop(State) ->
  Coordinator = State#state.coordinator,
  Timeout = State#state.waiting_time,
  NewState = receive
               {?ALIVE, _Node} -> State#state{waiting_time = infinity};
               {?ELECTION, Node} when Node < node() ->
                 {?MODULE, Node} ! {?ALIVE, node()},
                 start_election(State);
               {?COORDINATOR, Node} -> set_coordinator(State, Node);
               {nodedown, Coordinator} -> start_election(State);
               {nodedown, _Node} -> State
             after
               Timeout -> win(State)
             end,
  loop(NewState).

start_election(#state{nodes = Nodes} = State) ->
  lists:foreach(fun(X) -> {?MODULE, X} ! {?ELECTION, node()} end, [Node || Node <- Nodes, Node > node()]),
  State#state{waiting_time = ?WAIT_TIME}.

win(#state{nodes = Nodes} = State) ->
  io:fwrite("Node ~s won electoin.~n", [node()]),
  lists:foreach(fun(X) -> {?MODULE, X} ! {?COORDINATOR, node()} end, [Node || Node <- Nodes, Node < node()]),
  set_coordinator(State, node()).


set_coordinator(State, Coordinator) ->
  io:format("Node ~p has changed coordinator to ~p~n", [node(), Coordinator]),
  monitor_node(State#state.coordinator, false),
  monitor_node(Coordinator, true),
  State#state{coordinator = Coordinator, waiting_time = infinity}.
