
library(tidyverse)

# download S2
source_url <- "https://github.com/google/s2geometry/archive/v0.9.0.zip"
curl::curl_download(source_url, "data-raw/s2-source.tar.gz")
unzip("data-raw/s2-source.tar.gz", exdir = "data-raw")

# make sure the dir exists
s2_dir <- list.files("data-raw", "^s2geometry-[0-9.]+", include.dirs = TRUE, full.names = TRUE)
stopifnot(dir.exists(s2_dir), length(s2_dir) == 1)
src_dir <- file.path(s2_dir, "src/s2")

# headers live in inst/include
# keeping the directory structure means that
# we don't have to update any source files (beause of header locations)
headers <- tibble(
  path = list.files(file.path(s2_dir, "src", "s2"), "\\.(h|inc)$", full.names = TRUE, recursive = TRUE),
  final_path = str_replace(path, ".*?s2/", "inst/include/s2/")
)

# If source files are in src/ with no subdirectories
# We can use the built-in R Makefile with few modifications
# in Makevars. Here, we replace "/" with "__"
source_files <- tibble(
  path = list.files(file.path(s2_dir, "src", "s2"), "\\.cc$", full.names = TRUE, recursive = TRUE),
  final_path = str_replace(path, ".*?src/", "src/") %>%
    str_replace_all("/", "__") %>%
    str_replace("^.*?s2__", "src/")
) %>%
  filter(!str_detect(path, "_test\\."))

# clean source dir
current_source_files <- tibble(
  path = list.files("src", "\\.(h|hpp|cpp|o|cc)$", full.names = TRUE, recursive = TRUE)
) %>%
  filter(!str_detect(path, "^src/(libs2-|Rcpp|Makevars)"))

unlink(current_source_files$path)
unlink("inst/include/s2", recursive = TRUE)

# create destination dirs
dest_dirs <- c(
  headers %>% pull(final_path),
  source_files %>% pull(final_path)
) %>%
  dirname() %>%
  unique()
dest_dirs[!dir.exists(dest_dirs)] %>% walk(dir.create, recursive = TRUE)

# copy source files
stopifnot(
  file.copy(headers$path, headers$final_path),
  file.copy(source_files$path, source_files$final_path)
)

# reminders about manual modifications that are needed
# for build to succeed
print_next <- function() {
  cli::cat_rule("Manual modifications")
  cli::cat_bullet(
    "inst/include/s2/base/logging.h: ",
    "Added a 'getter' for `S2LogMessage::_severity` (silences -Wunused_member)"
  )
  cli::cat_bullet(
    "inst/include/s2/third_party/absl/base/dynamic_annotations.h: ",
    "Remove pragma suppressing diagnostics"
  )
  cli::cat_bullet(
    "inst/include/s2/base/port.h: ",
    "Add `|| defined(_WIN32)` to `#if defined(__ANDROID__) || defined(__ASYLO__)` (2 lines)"
  )
  cli::cat_bullet("Replace `abort()` with `cpp_compat_abort()`")
  cli::cat_bullet("Replace `cerr`/`cout` with `cpp_compat_cerr`/`cpp_compat_cout`")
  cli::cat_bullet("Replace `srandom()` with `cpp_compat_srandom()`")
  cli::cat_bullet("Replace `random()` with `cpp_compat_random()`")
}

print_next()
