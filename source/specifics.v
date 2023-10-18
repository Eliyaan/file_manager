module main

import os

fn (mut app App) go_in() {
	if app.dir_list != [] {
		if os.is_dir(app.dir_list[app.actual_i]) {
			if app.actual_path[app.actual_path.len - 1].ascii_str() != '\\' {
				app.actual_path = '${app.actual_path}\\${app.dir_list[app.actual_i]}'
			} else {
				app.actual_path = '${app.actual_path}${app.dir_list[app.actual_i]}'
			}
			os.chdir(app.actual_path) or {
				er('go_in ${err}')
				app.chdir_error = '${err}'
			}
		} else {
			file_ext := os.file_ext(app.dir_list[app.actual_i])
			if file_ext in app.associated_apps{
				spawn os.execute('${app.associated_apps[file_ext]} \"${app.actual_path + '/' + app.dir_list[app.actual_i]}\"')
			}else{
				spawn os.execute('${app.associated_apps["else"]} \"${app.actual_path + '/' + app.dir_list[app.actual_i]}\"')
			}
		}
	}
	app.last_event = 'go_in'
}

fn (mut app App) find_last_dir() int {
	if app.last_event == 'left' {
		mut last_dir := app.old_actual_path[app.actual_path.len..]
		if last_dir[0].ascii_str() == '\\' {
			last_dir = last_dir[1..]
		}
		for i, elem in app.dir_list {
			if elem == last_dir {
				return i
			}
		}
		er(last_dir.str())
	}
	return 0
}

fn (mut app App) update_dir_list() {
	app.dir_list = os.ls(app.actual_path) or { panic(err) }
	mut dirs := app.dir_list.filter(os.is_dir(os.abs_path(it)))
	dirs.sort(a < b)
	mut files := app.dir_list.filter(!os.is_dir(os.abs_path(it)))
	files.sort(a < b)
	app.dir_list = []string{cap:dirs.len+files.len}
	app.dir_list << dirs
	app.dir_list << files
}

fn (mut app App) draw_box(start_x int, start_y int, finish_x int, finish_y int) {
	mut x_bar := ""
	for _ in start_x+1..finish_x-1{
		x_bar += '\u2500' // u2500 https://www.utf8-chartable.de/unicode-utf8-table.pl
	}
	end_pos := if start_x != 0 {finish_x-1} else {finish_x}
	app.tui.draw_text(start_x, start_y, "\u256D${x_bar}\u256E")
	for i in start_y+1..finish_y{
		app.tui.draw_text(start_x, i, "\u2502")
		app.tui.draw_text(end_pos, i, "\u2502")
	}
	app.tui.draw_text(start_x, finish_y, "\u2570${x_bar}\u256F")
	//Debug:
	//app.tui.draw_text(if start_x != 0 {start_x+1} else {start_x+2}, finish_y-1, "$start_x, $start_y, $finish_x, $finish_y")
}

fn (mut app App) draw_bar(start_x int, start_y int, finish_x int) {
	mut x_bar := ""
	for _ in start_x+1..finish_x-1{
		x_bar += '\u2500' // u2500 https://www.utf8-chartable.de/unicode-utf8-table.pl
	}
	app.tui.draw_text(start_x, start_y, "\u251C${x_bar}\u2524")
}

fn command_execute(cmd_text string) {
	result := os.execute("$start_path\\exec_cmd.bat $cmd_text")
	os.write_file('$start_path/cmd_output.txt', result.output) or { panic(err) }
	os.execute('start \" \" $start_path/cmd_output.txt')
}

fn (mut app App) reset_search() {
	app.search_mode = false
	app.search_results = []
	app.search_success = false
	app.search_time = 0.0
	app.search_i = -1
	app.search_scroll = 0
}

fn (mut app App) reset_fav() {
	app.fav_index = 0
	app.fav_mode = false
	app.fav_scroll = 0
}

fn (mut app App) reset_question() {
	app.question_mode = ""
	app.question_answer = false
}

fn (mut app App) reset_edit() {
	app.edit_text = ""
	app.edit_mode = ""
}
