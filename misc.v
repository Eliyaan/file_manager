module main

import os

fn er(problem string) {
	os.write_file('$start_path/error_logs', problem) or { panic(err) }
}

fn space_nb(nb string) string {
	mut result := ''
	for i, chr in nb {
		result += chr.ascii_str()
		if (nb.len - 1 - i) % 3 == 0 {
			result += ' '
		}
	}
	return result
}
