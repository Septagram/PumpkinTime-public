<?php

#!/bin/bash
# Copyright (c) 2013, Igor Novikov
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

    function query ($query) {
        global $dbc;
        $stmt = $dbc->prepare ($query);
        if (!$stmt)
            throw new Exception ('Cannot create prepared statement: ' . $dbc->error);

        if (func_num_args() > 1) {
            $arg_string = func_get_arg (1);
            $arg_values = array_slice (func_get_args(), 2);
            while (!is_array ($arg_values) || !is_array ($arg_values [0])) {
                $arg_values = array ($arg_values);
            };
            if (is_array ($arg_values [0] [0])) {
                $arg_values = $arg_values [0];
            };

            $params = array();
            $bind_args = array ($arg_string);
            for ($i = 0; $i < strlen ($arg_string); $i ++) {
                $params [$i] = null;
                $bind_args[] =& $params [$i];
            };
            if (!call_user_func_array (array ($stmt, 'bind_param'), $bind_args))
                throw new Exception ('Cannot bind arguments to the prepared statement: ' . $stmt->error);

            foreach ($arg_values as $arg_set) {
                foreach ($arg_set as $i => $v) {
                    $params [$i] = $v;
                };
                if (!$stmt->execute())
                    throw new Exception ('Cannot execute prepared statement: ' . $stmt->error);
            };
        } else {
            if (!$stmt->execute())
                throw new Exception ('Cannot execute prepared statement: ' . $stmt->error);
        };

        if ($metadata = $stmt->result_metadata()) {
            $stmt->store_result();
            $bind_args = $res = $row = array();
            while ($field = $metadata->fetch_field()) {
                $bind_args[] =& $row [$field->name];
            };
            call_user_func_array (array ($stmt, 'bind_result'), $bind_args);

            while ($stmt->fetch()) {
                $row_to =& $res[];
                $row_to = array();
                foreach ($row as $k => $v) {
                    $row_to [$k] = $v;
                };
            };
        } else {
            $res = null;
        };

        return $res;
    };

    function query_or_die ($query)
    {
        global $dbc;
        $data = mysqli_query ($dbc, $query)
            or die ('Error executing query: ' . mysqli_error ($dbc));
        return $data;
    }

    function escape_sql ($string)
    {
        global $dbc;
        return mysqli_real_escape_string ($dbc, trim ($string));
    }

    function account ($account_id = null) {
        static $memo = array();
        if (!isset ($account_id))
            return account (session ('account_id'));
        if (array_key_exists ($account_id, $memo))
            return $memo [$account_id];
        $res = query ('
            SELECT
                account_id,
                username,
                session_date,
                CURRENT_DATE() AS today_date
            FROM account
            WHERE account_id = ?
        ', 'i', $account_id);
        return $memo [$account_id] = count ($res) === 1 ? $res [0] : null;
    };

    function settings ($account_id = null) {
        static $memo = array();
        if (!isset ($account_id))
            return settings (session ('account_id'));
        if (array_key_exists ($account_id, $memo))
            return $memo [$account_id];
        $res = array();
        foreach (query ('
            SELECT
               setting.short_name AS name,
               IF( account_setting.account_setting_id IS NOT NULL,
                   account_setting.value, setting.default_value ) AS value
            FROM setting
            LEFT JOIN account_setting
               ON setting.setting_id = account_setting.setting_id
               AND account_setting.account_id = ?
            ORDER BY setting.sort_index ASC, setting.name ASC
        ', 'i', $account_id) as $setting) {
            $res [$setting ['name']] = $setting ['value'];
        };
        return $memo [$account_id] = $res;
    };

    function session_status ($date, $account_id = null) {
        if (!isset ($account_id))
            return session_status ($date, session ('account_id'));

        $last_pomodoro = query ('
            SELECT
                end,
                is_interrupted
            FROM pomodoro
                WHERE account_id = ? AND session_date = ?
            ORDER BY begin DESC
            LIMIT 1
        ', 'is', $account_id, $date);

        if (count ($last_pomodoro) === 0)
            return 'none';
        else if (!isset ($last_pomodoro [0] ['end']))
            return 'incomplete';
        else if (!$last_pomodoro [0] ['is_interrupted'])
            return 'complete';
        else
            return 'interrupt';
    };

    function possible_settings()
    {
        $res = array();
        $query =    "SELECT * FROM setting ORDER BY sort_index ASC, name ASC";
        $data = query_or_die ($query);
        while ($row = mysqli_fetch_assoc ($data))
            $res [$row ['short_name']] = $row;
        return $res;
    }

    function last_pomodoro_where_clause ($only_open = false)
    {
        global $account;
        if (empty ($account))
            die ('Attempt to access the last pomodoro without an active account.');
        $account_id = $account ['account_id'];
        $session_date = $account ['session_date'];
        $open_clause = $only_open ? 'AND end IS NULL ' : '';
        return  "WHERE account_id = '$account_id' AND session_date = '$session_date'\n" .
                "$open_clause ORDER BY begin DESC LIMIT 1";
    }

    function last_pomodoro ($only_open = false, $session = null)
    {
        // If location is supplied first, swap variables:
        if (is_array ($only_open))
            list ($session, $only_open) = array ($only_open, $session);
        
        if (is_array ($session))
        {
            $timetable = $session ['timetable'];
            for ($i = count ($timetable) - 1; $i >= 0; $i --)
            {
                $microsession = $timetable [$i];
                for ($j = count ($microsession ['events']) - 1; $j >= 0; $j --)
                {
                    $check = $microsession ['events'] [$j];
                    if ($check ['type'] == 'pomodoro')
                    {
                        if ($only_open && $check ['status'] != 'in_progress')
                            return array ('status' => 'free');
                        $pomodoro = $check;
                        $pomodoro ['is_interrupted'] = $pomodoro ['status'] == 'interrupt' ? 1 : 0;
                        // ^ this is just so that the function returns the same form of result,
                        //   regardless of whether it's called with a timetable or not
                        $pomodoro_status_to_session_status
                            = array ( 'in_progress' => 'pomodoro',
                                      'interrupt'   => 'interrupt',
                                      'complete'    => 'break' );
                        $pomodoro ['status'] = $pomodoro_status_to_session_status [$pomodoro ['status']];
                        return $pomodoro;
                    }
                }
            }
            return array ('status' => 'free');
        } else {
            global $session_date;
            if (empty ($session_date))
                $status = 'free';
            else {
                $query =    "SELECT begin, end, is_interrupted, overdrive\n" .
                            "FROM pomodoro\n" .
                            last_pomodoro_where_clause ($only_open);
                $data = query_or_die ($query);
                if ($pomodoro = mysqli_fetch_assoc ($data))
                    $status =   $pomodoro ['end'] == null         ? 'pomodoro'  :
                               ($pomodoro ['is_interrupted'] == 1 ? 'interrupt' : 'break');
                else
                    $status = 'free';
            }
            $pomodoro ['status'] = $status;
            return $pomodoro;
        }
    }

    function session_totals ($timetable)
    {
        $totals = array ( 'pomodoros'       => 0,
                          'time'            => 0,
                          'achievements'    => 0,
                          'overdrive'       => 0 );
        foreach ($timetable as &$microsession)
        {
            foreach ($microsession ['events'] as &$pomodoro)
                if ($pomodoro ['type'] == 'pomodoro')
            {
                if ($pomodoro ['status'] == 'complete')
                    $totals ['pomodoros'] ++;
                if (isset ($pomodoro ['end']))
                    $totals ['time'] += $pomodoro ['end'] - $pomodoro ['begin'];
                $totals ['achievements'] += count ($pomodoro ['achievements']);
                $totals ['overdrive'] += $pomodoro ['overdrive'];
            }
        }
        $totals ['time'] = gmdate ('H:i', $totals ['time']);
        $totals ['overdrive'] = gmdate ($totals ['overdrive'] >= 3600 ?'H:i:s' : 'i:s',
                                        $totals ['overdrive']);
        return $totals;
    }

    function load_session_array ($date1 = null, $date2 = null)
    {
        global $account_id, $account, $session_date, $settings;
        if (!isset ($date1))
            $date1 = $session_date;
        if (!isset ($date2))
            $date2 = $date1;
        $date1 = escape_sql ($date1);
        $date2 = escape_sql ($date2);
        $query =    "   SELECT\n" .
                    "       session_date,\n" .
                    "       begin AS moment,\n" .
                    "       'begin' AS event,\n" .
                    "       pomodoro_id AS id,\n" .
                    "       NULL AS summary,\n" .
                    "       0 AS overdrive\n" .
                    "   FROM pomodoro\n" .
                    "   WHERE account_id = '$account_id'\n" .
                    "       AND session_date >= '$date1'\n" .
                    "       AND session_date <= '$date2'\n" .
                    "UNION\n" .
                    "   SELECT\n" .
                    "       session_date,\n" .
                    "       end AS moment,\n" .
                    "       IF(is_interrupted, 'interrupt', 'complete') AS event,\n" .
                    "       pomodoro_id AS id,\n" .
                    "       NULL as summary,\n" .
                    "       overdrive\n" .
                    "   FROM pomodoro\n" .
                    "   WHERE account_id = '$account_id'\n" .
                    "       AND session_date >= '$date1'\n" .
                    "       AND session_date <= '$date2'\n" .
                    "       AND end IS NOT NULL\n" .
                    "UNION\n" .
                    "   SELECT\n" .
                    "       session_date,\n" .
                    "       achievement_time AS moment,\n" .
                    "       'achievement' AS event,\n" .
                    "       achievement_id AS id,\n" .
                    "       summary,\n" .
                    "       0 AS overdrive\n" .
                    "   FROM achievement\n" .
                    "   WHERE account_id = '$account_id'\n" .
                    "       AND session_date >= '$date1'\n" .
                    "       AND session_date <= '$date2'\n" .
                    "ORDER BY session_date ASC, moment ASC";
        $data = query_or_die ($query);
        $res = array();
        $session = $nullref = null;

        while ($event = mysqli_fetch_assoc ($data))
        {
            if (!isset ($session ['date']) || $session ['date'] != $event ['session_date'])
            {
                if (isset ($session))
                    $session ['totals'] = session_totals ($session ['timetable']);
                $session =& $res [$event ['session_date']];
                $session = array ( 'date'       => $event ['session_date'],
                                   'timetable'  => array() );
                $microsession   =& $nullref;
                $pomodoro       =& $nullref;
                $last_pomodoro  =& $nullref;
                $delayed_achievements = array();
            }

            switch ($event ['event'])
            {
            case 'begin':
                // If the last break qualifies for a long break, enter a new microsession:
                if (!isset ($last_pomodoro ['end']) ||
                    $event ['moment'] - $last_pomodoro ['end'] >= $settings ['short_break_max_length'])
                {
                    if ($microsession && isset ($last_pomodoro ['end']))
                        $microsession ['end'] = $last_pomodoro ['end'];
                    $microsession =& $session ['timetable'] [];
                    $microsession = array ( 'begin'     => $event ['moment'],
                                            'end'       => null,
                                            'events'    => array() );
                }

                // Otherwise, just open the pomodoro:
                $pomodoro =& $microsession ['events'] [];
                $pomodoro = array ( 'type'          => 'pomodoro',
                                    'pomodoro_id'   => $event ['id'],
                                    'begin'         => $event ['moment'],
                                    'end'           => null,
                                    'status'        => 'in_progress',
                                    'overdrive'     => 0,
                                    'achievements'  => $delayed_achievements );
                $delayed_achievements = array();
                $microsession ['end'] = null;
                break;

            case 'complete':
            case 'interrupt':
                $pomodoro ['end'] = $microsession ['end'] = $event ['moment'];
                $pomodoro ['status'] = $event ['event'];
                $pomodoro ['overdrive'] = $event ['overdrive'];
                $last_pomodoro =& $pomodoro;
                unset ($pomodoro);
                $pomodoro = null;
                break;
                
            case 'achievement':
                if (isset ($pomodoro))
                    $achievement =& $pomodoro ['achievements'] [];
                else if (isset ($last_pomodoro))
                    $achievement =& $last_pomodoro ['achievements'] [];
                else
                    $achievement =& $delayed_achievements[];
                $achievement  = array ( 'type'              => 'achievement',
                                        'achievement_id'    => $event ['id'],
                                        'time'              => $event ['moment'],
                                        'summary'           => $event ['summary'] );
                break;
            }
    
        }

        if (isset ($session))
            $session ['totals'] = session_totals ($session ['timetable']);

        return $res;
    }

    function load_session ($date = null)
    {
        global $session_date;
        $sessions = load_session_array ($date);
        return isset ($sessions [$date]) ? $sessions [$date] : array();
    }
?>
