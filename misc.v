module main

import os
import term.ui as tui

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

fn key_str(code tui.KeyCode) string {
	return match code {
		.underscore {
			 "_"
		}
		.period {
			 "."
		}
		.comma {
			 ","
		}
		.colon {
			 ":"
		}
		.slash {
			 "/"
		}
		.question_mark {
			 "?"
		}
		.exclamation {
			 "!"
		}
		.minus {
			 "-"
		}
		.space {
			 " "
		}
		.semicolon {
			 ";"
		}
		.double_quote {"\""}
		.hashtag {"#"}
		.dollar {"$"}
		.percent {"%"}
		.ampersand {"&"}
		.single_quote {"'"}
		.left_paren {"("}
		.right_paren {")"}
		.asterisk {"*"}
		.plus {"+"}
		._0 {"0"}
		._1 {"1"}
		._2 {"2"}
		._3 {"3"}
		._4 {"4"}
		._5 {"5"}
		._6 {"6"}
		._7 {"7"}
		._8 {"8"}
		._9 {"9"}
		.less_than {"<"}
		.greater_than {">"}
		.equal {"="}
		.at {"@"}
		else {code.str()}
	}
}