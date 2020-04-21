# Copyright 2020 Adobe
# All Rights Reserved.

# NOTICE: Adobe permits you to use, modify, and distribute this file in
# accordance with the terms of the Adobe license agreement accompanying
# it. If you have received this file from a source other than Adobe,
# then your use, modification, or distribution of it requires the prior
# written permission of Adobe.

defmodule BotArmy.LogFormatters.JSONLogFormatter do
  @moduledoc """
  Use this logger formatter for nice JSON formatted logs with information useful for
  syncing timing.

  Based on https://github.com/soundtrackyourbrand/exlogger, but uses unix epoch
  timestamps and shows errors.
  """

  @spec format(
          Logger.level(),
          Logger.message(),
          Logger.Formatter.time(),
          Logger.Formatter.keyword()
        ) :: IO.chardata()
  def format(level, message, timestamp, metadata) do
    {{y, mo, d}, {h, m, s, mm}} = timestamp

    date_time = %DateTime{
      calendar: Calendar.ISO,
      year: y,
      month: mo,
      day: d,
      zone_abbr: "UTC",
      hour: h,
      minute: m,
      second: s,
      microsecond: {mm * 1000, 6},
      utc_offset: 0,
      std_offset: 0,
      time_zone: "Etc/UTC"
    }

    unix_timestamp = DateTime.to_unix(date_time, :millisecond)

    run_id = BotArmy.SharedData.get(:bot_run_id)

    bot_run_log_data =
      if run_id do
        %{"bot_run_id" => run_id}
      else
        %{}
      end

    default_log_data = %{
      "msg" => "#{message}",
      "level" => level,
      "timestamp" => unix_timestamp
    }

    log_data =
      default_log_data
      |> Map.merge(bot_run_log_data)
      |> Map.merge(Map.new(metadata))
      # pids aren't encodable and we don't really need them anyway
      |> Map.delete(:bot_pid)

    "#{Jason.encode!(log_data)}\n"
  rescue
    e ->
      "ERROR with log #{inspect(e)}\n" <>
        "Raw log: #{inspect(timestamp)} #{metadata[level]} #{level} #{message}\n"
  end
end
