package opm
import "core:fmt"
import "core:log"
import "core:runtime"
import "core:mem"
import "core:c"
import "core:strings"
import "core:os"
import "core:path/filepath"
import "core:path"
//import "../../lib/curl"

OpmDep :: struct {
	url:    string,
	name:   string,
	folder: string,
	force:  bool,
	after_install: DepAfterInstallProc,
}

OpmContext :: struct {
	default_folder: string,
	before_deps:    BeforeEachDepProc,
	deps:           [dynamic]OpmDep,
}

// Proc to be run after a single dep is installed
// This is set per dep in `after_install`
DepAfterInstallProc :: proc(ctx: ^OpmContext, dep: OpmDep, installed_path: string)

// Proc to be run before every dep in a project
// This is set in the `OpmContext` `before_deps`
BeforeEachDepProc :: proc(ctx: ^OpmContext, dep: OpmDep) -> bool


// Init an OpmContext.
// Not doing much right now and defaults the save folder to `./packages` in the directory opm was run
init_deps :: proc() -> OpmContext {
	ctx: OpmContext
	ctx.default_folder = "./packages"

	return ctx
}


// Add a dep just by url string. 
// folder will come from the `OpmContext` default folder
// name will be the base name of the url passed in.
add_dep_url :: proc(ctx: ^OpmContext, url: string) {
	append(&ctx.deps, OpmDep {
			url = url,
		})
}

// Pass in an opm dep manually.
// Use this version to set any custom things you might want like:
// after_install hook
// a different install folder
// a different folder name than the default one taken from the url
// you can also set to force install a dependency.
add_dep_dep :: proc(ctx: ^OpmContext, dep: OpmDep) {
	append(&ctx.deps, dep)
}


add_dep :: proc{add_dep_url, add_dep_dep}

when ODIN_OS == "darwin" {

	foreign import libc "System.framework"
	foreign libc {
		mktemp :: proc(template: cstring) -> cstring ---
		mkdir :: proc(dir: cstring, mode: u16) -> c.int ---
		fwrite :: proc(
			data: rawptr,
			size: c.size_t,
			count: c.size_t,
			stream: os.Handle,
		) -> c.size_t ---
		fdopen :: proc(handle: os.Handle, mode: cstring) -> rawptr ---
		system :: proc(command: cstring) -> c.int ---
		fclose :: proc(file: rawptr) -> c.int ---
	}
}

// Get the flags to pass the collections argument to the compiler
// Returns all distinct collections as a string for whatever use you have in mind.
// Check demo.odin for implementation but usage might look like `odin build my thing $(opm collections)`
odin_collections_flags :: proc(ctx: ^OpmContext) -> string {
	res := make([dynamic]string);
	defer delete(res);
	touchedFolders : map[string]bool;
	for dep in ctx.deps {
		depFolder := ctx.default_folder
		folder := depFolder;
		if len(dep.folder) > 0 {
			depFolder = dep.folder
		}
		if folder not_in touchedFolders {
			touchedFolders[folder] = true;
			name := path.name(folder);
			append(&res, fmt.tprintf("-collection:{0}={1}", name, folder));
		}
	}

	return strings.join(res[:], " ");
}

// Removes all dependencies under `packages` folder
clean_deps :: proc(ctx: ^OpmContext) {
	for dep in ctx.deps {
		depFolder := ctx.default_folder
		depName := path.name(dep.url)
		if len(dep.folder) > 0 {
			depFolder = dep.folder
		}
		if len(dep.name) > 0 {
			depName = dep.name
		}
		folder := path.join(depFolder, depName)
		if old_dir, old_dir_err := os.stat(folder); old_dir_err == os.ERROR_NONE {
			path, _ := filepath.abs(folder);
			log.info("removing", path);
			system(strings.clone_to_cstring(fmt.tprintf("rm -rf {0}", path)));
		}
	}
}

// Uses git to install all dependencies listed with `add_dep`
// If the folder for a dep already exists opm will skip installing that dep unless `force` is set in the dep struct
// Remember to `add_dep` anything needed before running this
install_deps :: proc(ctx: ^OpmContext) {
	if info, err := os.stat(ctx.default_folder); err == os.ERROR_NONE {
		if !info.is_dir {
			log.error("Package location:", ctx.default_folder, "is not a directory")
			os.exit(1)
		}
	} else {
		mkdir(strings.clone_to_cstring(ctx.default_folder), 0o0777)
	}


	for dep in ctx.deps {
		if ctx.before_deps != nil {
			res := ctx.before_deps(ctx, dep)
			if !res {
				continue
			}
		}
		makeDir := false


		depFolder := ctx.default_folder
		depName := path.name(dep.url)
		if len(dep.folder) > 0 {
			depFolder = dep.folder
		}
		if len(dep.name) > 0 {
			depName = dep.name
		}
		folder := path.join(depFolder, depName)
		if old_dir, old_dir_err := os.stat(folder); old_dir_err == os.ERROR_NONE {
			if !dep.force {
				log.info("folder", folder, "exists skipping")
				continue
			}
		} else {
			makeDir = true
		}
		/*
		curlCtx := curl.easy_init();
		defer curl.easy_cleanup(curlCtx);

		url := strings.clone_to_cstring(fmt.tprintf("{0}/zipball/master", dep.url), context.temp_allocator);
		tmpDir, _ := os.getenv("TMPDIR");
		tempLoc := path.join(tmpDir, strings.clone_from_cstring(mktemp("opm_download.XXXXXX")));
		curlFP : os.Handle;
		if tempFile, tempErr := os.open(tempLoc, os.O_RDWR | os.O_CREATE, 0o0400 | 0o0200); tempErr == os.ERROR_NONE {
			curlFP = tempFile;
		} else {
			log.info(tempErr);
		}

		curlFile := fdopen(curlFP, "w");
		curl.easy_setopt(curlCtx, curl.OPT_URL, url);
		curl.easy_setopt(curlCtx, curl.OPT_WRITEFUNCTION, nil);
		curl.easy_setopt(curlCtx, curl.OPT_WRITEDATA, curlFile);
		curl.easy_setopt(curlCtx, curl.OPT_FOLLOWLOCATION, true)

		res := curl.easy_perform(curlCtx);

		fclose(curlFile);
		os.close(curlFP);
		*/

		if makeDir {
			res := mkdir(strings.clone_to_cstring(folder, context.temp_allocator), 0o0777)
			if res == -1 {
				log.error("couldnt make", folder)
				log.info(os.Errno(os.get_last_error()))
			}
		}

		log.info("fetching", dep.url);
		/*
		sysCommand := fmt.tprintf("unzip -q {0} -d {1}", tempLoc, folder);
		system(strings.clone_to_cstring(sysCommand));
		*//*
		sysCommand := fmt.tprintf("unzip -q {0} -d {1}", tempLoc, folder);
		system(strings.clone_to_cstring(sysCommand));
		*/
		gitUrl := fmt.tprintf("https://{0}.git", dep.url)
		gitClone := fmt.tprintf("git clone --quiet --depth 1 {0} {1}", gitUrl, folder)
		system(strings.clone_to_cstring(gitClone))

		if dep.after_install != nil {
			dep.after_install(ctx, dep, folder);
		}
	}
}
