package demo
import "../src/opm"
import "core:strings"
import "core:log"
import "core:os"
import "core:fmt"

main :: proc() {
	//context.logger = log.create_console_logger();
	ctx := opm.init_deps()

	opm.add_dep(&ctx, "github.com/powerc9000/odin_sqlite")

	command := ""

	if len(os.args) > 1 {
		command = os.args[1]
	}

	switch command {
	case "collections":
		fmt.println(opm.odin_collections_flags(&ctx))
	case "clean":
		opm.clean_deps(&ctx)
	case:
		opm.install_deps(&ctx)
	}


}
