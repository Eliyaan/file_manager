module main

import term.ui as tui
import time
import os
import toml

const (
	start_path = os.abs_path('')
)

/*
Can a tray app react to keyboard inputs ?
TODO :
R1:
+ apparition dans un dossier choisi
+ si ctrl + 1->9  jump au fichier dans x 
+ faire un release propre : -prod, tous les fichiers de config propres dans un zip

R2:
. multiple file selection 
. Tabs 
. clearer crash logs / no crashes of the app (but fails yeah)
. affichage des erreurs 
. affichage des erreurs d'exec de la commande
. Copier le path
. Copier le path de l'elem
. refonte de la config :
. access any parameter of config.toml in the tui (with guis), cleaner files etc
. add/suppr with short cut Favorites files
. find a way to redraw only the modified things (will enable the full custom bg) 
. favorite commands
. pouvoir changer les raccourcis de bases avec la config (ex: n pour nouveau fichier en j)
. refonte du code
. doc du code



- progress bar search
- progress bar paste folders
- copy name of elem
- config : colors
- zip
- config : choose your own border chars
- Launch programs (with extention name?) (avec truc comme l'autocomplétion sous la barre de recherche)
- diff algo tri
- app de notes inclue
- ide
-- refonte du code

? Protected files
? appui sur a->z / 0->9 emmène sur le prochain fichier contenant cette lettre
*/

struct App {
mut:
	tui &tui.Context = unsafe { nil }

	actual_path string = os.abs_path('')
	actual_i    int
	actual_scroll int
	dir_list    []FileInfo
	fav_folders []string
	frame_nb    int
	last_event  string
	fav_mode bool
	fav_index int
	fav_scroll int
	edit_mode string
	question_mode string
	question_answer bool
	edit_text string
	refresh bool
	sort_name string = "Sorted by name"
	copy_path string
	cut_mode bool
	cmd_mode bool
	cmd_text string
	search_mode bool
	search_text string
	search_results []FileInfo
	search_i int = -1
	search_success bool
	search_time f64
	search_scroll int
	help_mode bool

	old_actual_path string
	old_actual_i    int
	old_edit_mode string
	old_edit_text string
	old_question_mode string
	old_question_answer bool
	old_fav_mode bool
	old_fav_index int
	old_cmd_mode bool
	old_cmd_text string
	old_search_mode bool
	old_search_text string
	old_search_i int
	old_help_mode bool

	chdir_error string

	associated_apps map[string]string 
	key_binds map[string]string 
	bg_color []u8
	folder_highlight []u8
	choice_highlight []u8
	folder_font []u8
	file_highlight []u8
	fav_highlight []u8
	search_highlight []u8
}

fn event(e &tui.Event, x voidptr) {
	mut app := unsafe { &App(x) }
	app.chdir_error = ''
	if e.typ == .key_down {
		if app.edit_mode != ""{
			match e.code {
				.null {}
				.escape {
					app.reset_edit()
					app.last_event = "escape edit"
				}
				.backspace {
					if app.edit_text.len > 0{
						app.edit_text = app.edit_text[0..app.edit_text.len-1]
					}
				}
				.enter {
					match app.edit_mode { 
						"Name of the new folder:" {
							os.mkdir(os.join_path_single(app.actual_path, app.edit_text)) or {er("mkdir $err")}
							app.update_dir_list()
							app.reset_edit()
							app.last_event = "create folder escape edit"
						} 
						"Name of the new file:" {
							mut f := os.create(os.join_path_single(app.actual_path, app.edit_text)) or {er("create file $err");os.File{}}
							f.close()
							app.update_dir_list()
							app.reset_edit()
							app.last_event = "create file escape edit"
						}
						"Rename:" {
							os.rename("$app.actual_path\\${app.dir_list[app.actual_i].name}", "$app.actual_path\\$app.edit_text") or {er("rename $err")}
							app.update_dir_list()
							app.reset_edit()
							app.last_event = "rename"
						}
						else {}
					}
				}
				else{
					app.edit_text += key_str(e.code ,e.modifiers)
				}
			}
		} else if app.question_mode != "" {			
			match e.code {
				.right {app.question_answer = !app.question_answer}
				.left {app.question_answer = !app.question_answer}
				.enter {
					if app.question_answer{
						if app.question_mode == "Delete this file ?" {
							os.rm(os.join_path_single(app.actual_path, app.dir_list[app.actual_i].name)) or {er('rm $err')}
							app.update_dir_list()
							if app.dir_list.len > 0{
								app.actual_i = app.actual_i % app.dir_list.len
							}
							app.last_event = "deleted a file"
						}else{
							if app.question_mode == "Delete this folder ?" {
								os.rmdir_all(os.join_path_single(app.actual_path, app.dir_list[app.actual_i].name)) or {er('rmdir_all $err')}
								app.update_dir_list()
								if app.dir_list.len > 0{
									app.actual_i = app.actual_i % app.dir_list.len
								}
								app.last_event = "deleted a folder"
							}
						}
					}
					app.reset_question()
				}
				.escape {
					app.reset_question()
					app.last_event = "escape question"
				}
				else{}
			}
		} else if app.fav_mode{
			match e.code {
				.f {
					app.reset_fav()
				}
				.escape {
					app.reset_fav()
				}
				.up {
					if app.fav_folders != [] {
						if (app.fav_index - 1) == -1 {
							app.fav_index = app.fav_folders.len - 1
							if app.fav_folders.len > app.tui.window_height - 10 {
								app.fav_scroll = -app.tui.window_height + 14 + app.fav_index
							}
						} else {
							app.fav_index = app.fav_index - 1
						}
						if app.fav_folders.len > app.tui.window_height - 10 {
							if app.fav_index - 3 < app.fav_scroll  {
								if app.fav_scroll > 0 {
									app.fav_scroll -= 1
								}
							}
						}
					}
					app.last_event = 'fav up'
				}
				.down {
					if app.fav_folders != [] {
						app.fav_index = (app.fav_index + 1) % app.fav_folders.len
						if app.fav_folders.len > app.tui.window_height - 10 {
							if app.fav_index - app.fav_scroll > app.tui.window_height - 14 {
								app.fav_scroll = -app.tui.window_height + 14 + app.fav_index
							} else {
								if app.fav_index == 0 {
									app.fav_scroll = 0
								}
							}
						}
					}
					app.last_event = 'fav down'
				}
				.enter {
					app.actual_path = app.fav_folders[app.fav_index]
					app.reset_fav()
					os.chdir(app.actual_path) or {
						er('go in fav ${err}')
						app.chdir_error = '${err}'
					}
					app.update_dir_list()
					if app.dir_list.len > 0{
						app.actual_i = app.actual_i % app.dir_list.len
					}
				}
				.left {
					app.actual_path = app.fav_folders[app.fav_index]
					app.reset_fav()
					os.chdir(app.actual_path) or {
						er('go in fav ${err}')
						app.chdir_error = '${err}'
					}
					app.update_dir_list()
					if app.dir_list.len > 0{
						app.actual_i = app.actual_i % app.dir_list.len
					}
				}
				else{}
			}
		} else if app.cmd_mode {
			match e.code {
				.escape {
					app.cmd_mode = false
				}
				.enter {
					spawn command_execute(app.cmd_text)
					app.cmd_mode = false
				}
				.backspace {
					if app.cmd_text.len > 0{
						app.cmd_text = app.cmd_text[0..app.cmd_text.len-1]
					}
				}
				else {app.cmd_text += key_str(e.code, e.modifiers)}
			}
		} else if app.search_mode {
			match e.code {
				.escape {
					app.reset_search()
				}
				.enter {
					if app.search_i == -1{
						sw := time.new_stopwatch()
						app.search_results = search(app.search_text, app.actual_path)
						app.search_time = sw.elapsed().seconds()
						app.search_success = true
						app.refresh = true
					}else{
						if app.search_results[app.search_i].is_dir() {
							app.actual_path = app.search_results[app.search_i].full_path
							os.chdir(app.actual_path) or {
								er('go to w/ search ${err}')
								app.chdir_error = '${err}'
							}
							app.reset_search()
						} else {
							file_ext := os.file_ext(app.search_results[app.search_i].name)
							if file_ext in app.associated_apps{
								spawn os.execute('${app.associated_apps[file_ext]} \"${app.search_results[app.search_i].full_path}\"')
							}else{
								spawn os.execute('${app.associated_apps["else"]} \"${app.search_results[app.search_i].full_path}\"')
							}
						}
					}
				}
				.backspace {
					if app.search_text.len > 0{
						app.search_text = app.search_text[0..app.search_text.len-1]
					}
				}
				.up {
					if app.search_results != [] {
						if app.search_i - 1 <= -1 {
							app.search_i = app.search_results.len - 1
							if app.search_results.len > app.tui.window_height - 12 {
								app.search_scroll = -app.tui.window_height + 16 + app.search_i
							}
						} else {
							app.search_i = app.search_i - 1
						}
						if app.search_results.len > app.tui.window_height - 12 {
							if app.search_i - 3 < app.search_scroll  {
								if app.search_scroll > 0 {
									app.search_scroll -= 1
								}
							}
						}
					}
				}
				.down {
					if app.search_results != [] {
						app.search_i = (app.search_i + 1) % app.search_results.len
						if app.search_results.len > app.tui.window_height - 12 {
							if app.search_i - app.search_scroll > app.tui.window_height - 16 {
								app.search_scroll = -app.tui.window_height + 16 + app.search_i
							} else {
								if app.search_i == 0 {
									app.search_scroll = 0
								}
							}
						}
					}
				}
				else {app.search_text += key_str(e.code, e.modifiers); app.search_i = -1}
			}
		} else if app.help_mode {
			match e.code {
				.question_mark {
					app.help_mode = false
				}
				.escape {
					app.help_mode = false
				}
				else{}
			}
		}else {
			match e.code {
				.question_mark {
					app.help_mode = true
				}
				.c  {
					if e.modifiers.has(.ctrl){
						app.copy_path = os.abs_path(app.dir_list[app.actual_i].name)
						app.refresh = true
						app.cut_mode = false
						app.last_event = 'copy'
					}else {
						app.cmd_mode = true
						app.cmd_text = ""
						app.last_event = 'cmd mode'
					}
				}
				.x  {
					if e.modifiers.has(.ctrl){
						app.copy_path = os.abs_path(app.dir_list[app.actual_i].name)
						app.refresh = true
						app.cut_mode = true
						app.last_event = 'cut'
					}
				}
				.v  {
					if e.modifiers.has(.ctrl){
						if app.cut_mode {
							os.mv(app.copy_path, app.actual_path+"\\"+os.file_name(app.copy_path)) or {er("cut paste file $err")}
						}else{
							if e.modifiers.has(.shift){
								os.cp_all(app.copy_path, app.actual_path+"\\"+os.file_name(app.copy_path), true) or {er("copy paste overwrite $err")}
							}else{
								if !os.is_dir(app.copy_path){
									os.cp(app.copy_path, app.actual_path+"\\"+os.file_name(app.copy_path)) or {er("copy paste file $err")}
								}else{
									os.cp_all(app.copy_path, app.actual_path+"\\"+os.file_name(app.copy_path), false) or {er("copy paste dir $err")}
								}
							}
						}
						app.update_dir_list()
						if app.dir_list.len > 0{
							app.actual_i = app.actual_i % app.dir_list.len
						}
						app.refresh = true
						app.last_event = 'paste'
					}
				}
				.up {
					if app.dir_list != [] {
						if (app.actual_i - 1) == -1 {
							app.actual_i = app.dir_list.len - 1
							if app.dir_list.len > app.tui.window_height - 5 {
								app.actual_scroll = -app.tui.window_height + 8 + app.actual_i
							}
						} else {
							app.actual_i = app.actual_i - 1
						}
						if app.dir_list.len > app.tui.window_height - 5 {
							if app.actual_i - 3 < app.actual_scroll  {
								if app.actual_scroll > 0 {
									app.actual_scroll -= 1
								}
							}
						}
					}
					app.last_event = 'up'
				}
				.down {
					if app.dir_list != [] {
						app.actual_i = (app.actual_i + 1) % app.dir_list.len
						if app.dir_list.len > app.tui.window_height - 5 {
							if app.actual_i - app.actual_scroll > app.tui.window_height - 8 {
								app.actual_scroll = -app.tui.window_height + 8 + app.actual_i
							} else {
								if app.actual_i == 0 {
									app.actual_scroll = 0
								}
							}
						}
					}
					app.last_event = 'down'
				}
				.left {
					app.actual_path = os.abs_path(os.dir(app.actual_path) + '\\')
					os.chdir(app.actual_path) or {
						er('left chdir ${err} ${app.actual_path}')
						''
					}
					app.last_event = 'left'
				}
				.right {
					app.go_in()
					app.actual_scroll = 0
				}
				.enter {
					app.go_in()
					app.actual_scroll = 0
				}
				.n {
					if !e.modifiers.has(.shift) {
						app.edit_mode = 'Name of the new file:'
						app.last_event = 'new_file'
					}else{
						app.edit_mode = 'Name of the new folder:'
						app.last_event = 'new_dir'
					}
				}
				.r {
					if e.modifiers.has(.shift){
						app.update_dir_list()
						if app.dir_list.len > 0{
							app.actual_i = app.actual_i % app.dir_list.len
						}
						app.refresh = true
						app.last_event = 'refresh'
					}else{
						app.edit_mode = 'Rename:'
						app.last_event = 'rename'
					}
				}
				.delete {
					if app.dir_list != [] {
						if !app.dir_list[app.actual_i].is_dir() {
							app.question_mode = "Delete this file ?"
						}else{
							if e.modifiers.has(.shift) {
								app.question_mode = "Delete this folder ?"
							}
						}
						app.last_event = 'delete'
					}
				}
				.escape {
					exit(0)
				}
				.q {
					exit(0)
				}
				.f {
					app.fav_mode = true
					app.last_event = 'fav mode'
				}
				.space {
					app.search_mode = true
					app.search_text = ""
					app.last_event = 'search mode'
				}
				else {
					if e.code.str() in app.key_binds {
						spawn os.execute(app.key_binds[e.code.str()])
						app.refresh = true
						app.last_event = 'exec'
					}
				}
			}
		}
		
	}else if e.typ == .resized {
		app.refresh = true
	}
}

fn (mut app App) render() {
	app.tui.clear()
	app.tui.set_bg_color(r: app.bg_color[0], g: app.bg_color[1], b: app.bg_color[2])
	//app.tui.draw_rect(0, 0, app.tui.window_width, app.tui.window_height)
	app.tui.set_color(r: 255, g: 255, b: 255) // white font

	
	app.tui.draw_text(0, 0, '${app.actual_path}')
	app.tui.draw_text(app.tui.window_width-app.copy_path.len-12, 0, 'Clipboard : ${app.copy_path}')
	// Draw the box around the files
	app.draw_box(0, 2, app.tui.window_width, app.tui.window_height-1)
	app.tui.draw_text(3, 2, app.sort_name)
	// Draw the files
	app.tui.set_color(r: app.folder_font[0], g: app.folder_font[1], b: app.folder_font[2]) // color for dirs
	mut encountered_file := false
	if app.chdir_error == '' {
		for i, file in app.dir_list#[0+app.actual_scroll..app.tui.window_height+app.actual_scroll-4] {
			pos := i+3
			if file.is_dir() {
				if i == app.actual_i-app.actual_scroll {
					app.tui.set_bg_color(r: app.folder_highlight[0], g: app.folder_highlight[1], b: app.folder_highlight[2])
				}
				app.tui.draw_text(3, pos, '${file.name}')
				if i == app.actual_i-app.actual_scroll {
					app.tui.set_bg_color(r: app.bg_color[0], g: app.bg_color[1], b: app.bg_color[2])
				}
			} else {
				if encountered_file == false {
					app.tui.set_color(r: 255, g: 255, b: 255) // file font color
					encountered_file = true
				}
				if i == app.actual_i-app.actual_scroll {
					app.tui.set_bg_color(r: app.file_highlight[0], g: app.file_highlight[1], b: app.file_highlight[2])
				}
				app.tui.draw_text(3, pos, '${file.name}')
				if i == app.actual_i-app.actual_scroll {
					app.tui.set_bg_color(r: app.bg_color[0], g: app.bg_color[1], b: app.bg_color[2])
				}
			}
		}
		if app.dir_list.len == 0 {
			app.tui.draw_text(2, 3, 'Empty directory')
		} else {
			if app.search_results != [] && app.search_i != -1 {
				bottom_text := '${(if !app.search_results[app.search_i].is_dir() {space_nb(app.search_results[app.search_i].file_size().str()) + 'o'} else {'Directory'}):-15} | Modified the ${app.search_results[app.search_i].write_time().nice_time()} | Accessed the ${app.search_results[app.search_i].access_time().nice_time()} | Creatied the ${app.search_results[app.search_i].creation_time().nice_time()}'
				app.tui.draw_text(0, app.tui.window_height, if bottom_text.len > app.tui.window_width {bottom_text[0..app.tui.window_width]} else {bottom_text})
			}else{
				bottom_text := '${(if !app.dir_list[app.actual_i].is_dir() {space_nb(app.dir_list[app.actual_i].file_size().str()) + 'o'} else {'Directory'}):-15} | Modified the ${app.dir_list[app.actual_i].write_time().nice_time()} | Accessed the ${app.dir_list[app.actual_i].access_time().nice_time()} | Created the ${app.dir_list[app.actual_i].creation_time().nice_time()}'
				app.tui.draw_text(0, app.tui.window_height, if bottom_text.len > app.tui.window_width {bottom_text[0..app.tui.window_width]} else {bottom_text})
			}
		}
	} else {
		app.tui.draw_text(1, 2, app.chdir_error)
	}
	app.tui.set_color(r: 255, g: 255, b: 255)

	if app.edit_mode != "" {
		app.draw_box(app.tui.window_width/10, (app.tui.window_height-1)/2-1, app.tui.window_width*9/10, (app.tui.window_height-1)/2+1)
		app.tui.draw_text(app.tui.window_width/10+2, (app.tui.window_height-1)/2-1, app.edit_mode)
		app.tui.draw_text(app.tui.window_width/10+2, (app.tui.window_height-1)/2, app.edit_text)
	}else if app.question_mode != "" {
		app.draw_box(app.tui.window_width/2-15, (app.tui.window_height-1)/2-2, app.tui.window_width/2+15, (app.tui.window_height-1)/2+1)
		app.tui.draw_text(app.tui.window_width/2-9, (app.tui.window_height-1)/2-1, app.question_mode)
		if app.question_answer{
			app.tui.set_bg_color(r: app.bg_color[0], g: app.bg_color[1], b: app.bg_color[2])
		}else{
			app.tui.set_bg_color(r: app.choice_highlight[0], g: app.choice_highlight[1], b: app.choice_highlight[2])
		}
		app.tui.draw_text(app.tui.window_width/2-3, (app.tui.window_height-1)/2,"No")
		if app.question_answer{
			app.tui.set_bg_color(r: app.choice_highlight[0], g: app.choice_highlight[1], b: app.choice_highlight[2])
		}else{
			app.tui.set_bg_color(r: app.bg_color[0], g: app.bg_color[1], b: app.bg_color[2])
		}
		app.tui.draw_text(app.tui.window_width/2, (app.tui.window_height-1)/2, "Yes")
		app.tui.set_bg_color(r: app.bg_color[0], g: app.bg_color[1], b: app.bg_color[2])
	}else if app.fav_mode {
		app.draw_box(app.tui.window_width/10, 5, app.tui.window_width*9/10, app.tui.window_height-4)
		app.tui.draw_text(app.tui.window_width/10+2, 5, "Favorites")
		for i, fav in app.fav_folders#[0+app.fav_scroll..app.tui.window_height-8-2+app.fav_scroll] {
			if app.fav_index-app.fav_scroll == i {
				app.tui.set_bg_color(r: app.fav_highlight[0], g: app.fav_highlight[1], b: app.fav_highlight[2])
			}
			app.tui.draw_text(app.tui.window_width/10+2, 6+i, fav)
			if app.fav_index-app.fav_scroll == i {
				app.tui.set_bg_color(r: app.bg_color[0], g: app.bg_color[1], b: app.bg_color[2])
			}
		}
	} else if app.cmd_mode {
		app.draw_box(app.tui.window_width/10, (app.tui.window_height-1)/2-1, app.tui.window_width*9/10, (app.tui.window_height-1)/2+1)
		app.tui.draw_text(app.tui.window_width/10+2, (app.tui.window_height-1)/2-1, "Enter your command")
		app.tui.draw_text(app.tui.window_width/10+2, (app.tui.window_height-1)/2, "> $app.cmd_text")
	} else if app.search_mode {
		if app.search_results != [] {
			app.draw_box(app.tui.window_width/10, 5, app.tui.window_width*9/10, app.tui.window_height-4)
			app.draw_bar(app.tui.window_width/10, 7, app.tui.window_width*9/10)
			for i, result in app.search_results#[0+app.search_scroll..app.tui.window_height-8-4+app.search_scroll] {
				if i == app.search_i-app.search_scroll{
					app.tui.set_bg_color(r: app.search_highlight[0], g: app.search_highlight[1], b: app.search_highlight[2])
				}
				app.tui.draw_text(app.tui.window_width/10+2, 8+i, "${result.full_path[app.actual_path.len..]}")
				if i == app.search_i-app.search_scroll{
					app.tui.set_bg_color(r: app.bg_color[0], g: app.bg_color[1], b: app.bg_color[2])
				}
			}
		}else {
			if app.search_success{
				app.draw_box(app.tui.window_width/10, 5, app.tui.window_width*9/10, 7+1+1)
				app.draw_bar(app.tui.window_width/10, 7, app.tui.window_width*9/10)
				app.tui.draw_text(app.tui.window_width/10+2, 8, " No results")
			}else{
				app.draw_box(app.tui.window_width/10, 5, app.tui.window_width*9/10, 7)
			}
		}
		title := if app.search_success { "Search - ${app.search_time}s" } else { "Search" }
		app.tui.draw_text(app.tui.window_width/10+2, 5, title)
		app.tui.draw_text(app.tui.window_width/10+3, 6, "${app.search_text}")
	}else if app.help_mode {
		app.draw_box(app.tui.window_width/10, 5, app.tui.window_width*9/10, app.tui.window_height-4)
		for i, line in os.read_lines("$start_path\\keybinds.txt")or{["read keybinds.txt not successful"]}{
			app.tui.draw_text(app.tui.window_width/10+2, 6+i, line)
		}		
		app.tui.draw_text(app.tui.window_width/10+2, 5, 'Help')
	}

	app.tui.set_cursor_position(0, 0)

	app.tui.reset()
	app.tui.flush()
}

fn frame(x voidptr) {
	mut app := unsafe { &App(x) }
	mut ask_render := false
	app.frame_nb = (app.frame_nb + 1) % 3600
	if app.old_actual_path != app.actual_path {
		app.update_dir_list()
		ask_render = true
		app.actual_i = app.find_last_dir()
		//app.actual_i = 0
		app.old_actual_path = app.actual_path
	} else {
		if app.frame_nb % 360 == 0 {
		}
	}
	if app.refresh{
		ask_render = true
		app.refresh = false
	}
	if app.old_actual_i != app.actual_i {
		ask_render = true
		app.old_actual_i = app.actual_i
	}else if app.old_edit_mode != app.edit_mode{
		ask_render = true
		app.old_edit_mode = app.edit_mode
	}else if app.old_edit_text != app.edit_text{
		ask_render = true
		app.old_edit_text = app.edit_text
	}else if app.old_question_answer != app.question_answer{
		ask_render = true
		app.old_question_answer = app.question_answer
	}else if app.old_question_mode != app.question_mode{
		ask_render = true
		app.old_question_mode = app.question_mode
	}else if app.old_fav_mode != app.fav_mode {
		ask_render = true
		app.old_fav_mode = app.fav_mode
	}else if app.old_fav_index != app.fav_index {
		ask_render = true
		app.old_fav_index = app.fav_index
	}else if app.old_cmd_mode != app.cmd_mode {
		ask_render = true
		app.old_cmd_mode = app.cmd_mode
	}else if app.old_cmd_text != app.cmd_text {
		ask_render = true
		app.old_cmd_text = app.cmd_text
	}else if app.old_search_mode != app.search_mode {
		ask_render = true
		app.old_search_mode = app.search_mode
	}else if app.old_search_text != app.search_text {
		ask_render = true
		app.old_search_text = app.search_text
	}else if app.old_search_i != app.search_i {
		ask_render = true
		app.old_search_i = app.search_i
	}else if app.old_help_mode != app.help_mode {
		ask_render = true
		app.old_help_mode = app.help_mode
	}

	if ask_render {
		app.render()
	}
}

fn (mut app App) initialisation() {
	app.tui.set_color(r: 255, g: 255, b: 255)
	app.update_dir_list()
	app.tui.set_bg_color(r: app.bg_color[0], g: app.bg_color[1], b: app.bg_color[2])
	//app.tui.draw_rect(0, 0, app.tui.window_width, app.tui.window_height)
}

fn main() {
	mut app := &App{}
	config := toml.parse_file("config.toml") or {er("Config file error $err"); println("juujuj"); toml.Doc{}}
	if config.value('exts_n_paths') == toml.Any(toml.Null{}) {
		er("read config file error")
	}	
	tmp_array := config.value('exts_n_paths').array().map(it.string())
	if tmp_array.len%2 != 0 {
		eprintln("Error: elements in exts_n_paths (config.toml) should be in pairs")
		return
	}
	for i, elem in tmp_array{
		if i%2 == 0{
			app.associated_apps[elem] = tmp_array[i+1]
		}
	}
	app.fav_folders = config.value('favorite_folders').array().map(it.string())
	app.bg_color = config.value('bg_color').array().map(u8(it.int()))
	app.folder_highlight = config.value('folder_highlight').array().map(u8(it.int()))
	app.choice_highlight = config.value('choice_highlight').array().map(u8(it.int()))
	app.folder_font = config.value('folder_font').array().map(u8(it.int()))
	app.file_highlight = config.value('file_highlight').array().map(u8(it.int()))
	app.fav_highlight = config.value('fav_highlight').array().map(u8(it.int()))
	app.search_highlight = config.value('search_highlight').array().map(u8(it.int()))

	tmp_keybinds := config.value('keybinds').array().map(it.array())
	mut keybinds := [][]string{}
	for elem in tmp_keybinds {
		keybinds << elem.map(it.string())
	}
	for pair in keybinds {
		app.key_binds[pair[0]] = pair[1]
	}


	// os.ls()
	// os.abs_path()
	// os.is_dir()
	// os.is_dir_empty()
	// os.is_file()
	/*
	os.file_name(opath string) string
	os.file_ext(app.dir_list[app.actual_i])
	fn chdir(path string) !
chdir changes the current working directory to the new directory in path.

fn getwd() string
getwd returns the absolute path of the current directory.

fn dir(opath string) string
dir returns all but the last element of path, typically the path's directory.
After dropping the final element, trailing slashes are removed.
If the path is empty, dir returns ".". If the path consists entirely of separators, dir returns a single separator.
The returned path does not end in a separator unless it is the root directory.
	*/
	app.tui = tui.init(
		user_data: app
		event_fn: event
		frame_fn: frame
		window_title: "fm"
		hide_cursor: true
	)
	app.initialisation()
	app.tui.run()!
}