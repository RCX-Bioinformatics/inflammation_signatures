# Function to parse named logical arguments
type.convert.args <- function(x) {
  # Split the input string into argument-name pairs
  args_list <- strsplit(x, "=")
  names_list <- sapply(args_list, function(x) x[1])
  values_list <- sapply(args_list, function(x) x[2])
  
  # Create a named list of arguments
  args_named <- setNames(values_list, names_list)
  
  # Convert logical values (TRUE/FALSE) to actual logicals and leave other values as they are
  args_named <- lapply(args_named, function(x) {
    if (x %in% c("TRUE", "FALSE")) {
      return(as.logical(x))  # Convert "TRUE"/"FALSE" to logical
    } else {
      return(x)  # Leave other arguments, such as DATASET, as strings
    }
  })
  
  return(args_named)
}