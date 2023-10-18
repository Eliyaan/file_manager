import os

// win: FILETIME
// https://docs.microsoft.com/en-us/windows/win32/api/minwinbase/ns-minwinbase-filetime
struct Filetime {
	dw_low_date_time  u32
	dw_high_date_time u32
}

// win: WIN32_FIND_DATA
// https://docs.microsoft.com/en-us/windows/win32/api/minwinbase/ns-minwinbase-win32_find_dataw
struct FileInfo {
mut:
	dw_file_attributes    u32
	ft_creation_time      Filetime
	ft_last_access_time   Filetime
	ft_last_write_time    Filetime
	n_file_size_high      u32
	n_file_size_low       u32
	dw_reserved0          u32
	dw_reserved1          u32
	c_file_name           [260]u16 // max_path_len = 260
	c_alternate_file_name [14]u16  // 14
	dw_file_type          u32
	dw_creator_type       u32
	w_finder_flags        u16
	full_path string
}

[inline]
fn (file_info FileInfo) name() string {
	return unsafe { string_from_wide(&file_info.c_file_name[0]) }
}

[inline]
fn (file_info FileInfo) is_dir() bool {
	return file_info.dw_file_attributes & u32(C.FILE_ATTRIBUTE_DIRECTORY) != 0
}

fn list_content(path string) []FileInfo {
	mut find_file_data := FileInfo{}
	mut dir_files := []FileInfo{}
	// NOTE:TODO: once we have a way to convert utf16 wide character to utf8
	// we should use FindFirstFileW and FindNextFileW
	handle_to_find_files := C.FindFirstFile('${path}\\*'.to_wide(), voidptr(&find_file_data))
	first_filename := find_file_data.name()
	if first_filename != '.' && first_filename != '..' {
		find_file_data.full_path = "$path\\${find_file_data.name()}"
		dir_files << find_file_data
	}
	for C.FindNextFile(handle_to_find_files, voidptr(&find_file_data)) > 0 {
		find_file_data.full_path = "$path\\${find_file_data.name()}"
		filename := find_file_data.name()
		if filename != '.' && filename != '..' {
			dir_files << find_file_data
		}
	}
	C.FindClose(handle_to_find_files)
	return dir_files
}

fn main() {
	a := list_content(os.abs_path("")+"\\source")
	println(a[0].full_path)
	println(a[1].name())
	println(a[0].is_dir())
	println(a[1].is_dir())
}