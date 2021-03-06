defmodule HoneydewTest do
  use ExUnit.Case, async: false
  # pools register processes globally, so async: false
  def child_pids(supervisor) do
    supervisor
    |> Supervisor.which_children
    |> Enum.into(HashSet.new, fn {_, pid, _, _} -> pid end)
  end


  test "work_queue_name/2" do
    assert Honeydew.work_queue_name(Sender, :poolname) == :"Elixir.Honeydew.WorkQueue.Sender.poolname"
  end

  test "worker_supervisor_name/2" do
    assert Honeydew.worker_supervisor_name(Sender, :poolname) == :"Elixir.Honeydew.WorkerSupervisor.Sender.poolname"
  end

  test "starts a correct supervision tree" do
    {:ok, supervisor} = Honeydew.Supervisor.start_link(:poolname, Sender, [:state_here], workers: 7)
    assert [{:worker_supervisor, worker_supervisor, :supervisor, _},
            {:work_queue,              _work_queue, :worker,     _}] = Supervisor.which_children(supervisor)

    assert worker_supervisor |> Supervisor.which_children |> Enum.count == 7
  end

  test "calls the worker module's init/1 and keeps it as state" do
    {:ok, _} = Honeydew.Supervisor.start_link(:poolname_1, Sender, :state_here)

    Sender.call(:poolname_1, {:send_state, [self]})
    assert_receive :state_here
  end

  test "workers restart after crashing" do
    {:ok, supervisor} = Honeydew.Supervisor.start_link(:poolname_2, Sender, :state_here, workers: 10, max_failures: 3)

    [{:worker_supervisor, worker_supervisor, :supervisor, _}, _] = Supervisor.which_children(supervisor)

    before_crash = child_pids(worker_supervisor)
    assert Enum.count(before_crash) == 10

    Sender.cast(:poolname_2, :this_crash_is_intentional)

    # # let the pool restart the worker
    :timer.sleep 100

    after_crash = child_pids(worker_supervisor)
    assert Enum.count(after_crash) == 10

    # three workers crashed, so there should still be seven with the same pids before and after
    assert Set.intersection(before_crash, after_crash) |> Enum.count == 7
  end

end
