#' 10 sample to sample correlations
#' 
#' test data of 10 sample to sample correlations where samples are drawn
#' from two groups. Generated by rmflight from random distributions
#' 
#' @format matrix with 10 rows and 10 columns, with row and colnames
#' @source generated by rmflight
#' @name grp_cor
NULL

#' 10 sample meta-data
#' 
#' meta-data for \code{grp_cor}. 
#' 
#' @format data.frame with 10 rows, and 2 columns, \code{grp} defining with group
#' and \code{set}, defining the set.
#' @source generated by rmflight
#' @name grp_info
NULL

#' create set of disjoint colors
#' 
#' When multiple sample classes need to be visualized on a heatmap, it is useful
#' to be able to distinguish them by color. This function generates a set of colors
#' for sample classes
#' 
#' @param n_group how many groups should there be colors for
#' @param randomize should colors be randomized? (default is \code{NULL}). See \emph{details}.
#' 
#' @details the default for \code{randomize} is \code{NULL}, so that reordering
#'   the colors randomly is decided purely based on the number of colors requested.
#'   Currently, that cutoff is \emph{5} colors, less than that the colors will
#'   always be in the same order, for \emph{5} colors or more, they will
#'   be in a scrambled order, different each time unless \code{set.seed} is
#'   used. If \code{randomize} is \code{TRUE} or \code{FALSE}, then it overrides
#'   the defaults.
#' 
#' @importFrom colorspace rainbow_hcl
#' @export
generate_group_colors <- function(n_group, randomize = NULL){
  end_color <- 360 * (n_group - 1) / n_group
  group_color <- rainbow_hcl(n_group, c = 100, start = 0, end = end_color)
  
  
  
  if ((n_group < 5) && is.null(randomize)) {
    do_sample <- FALSE
  } else if ((n_group < 5) && is.logical(randomize)) {
    do_sample <- randomize
  } else if ((n_group >= 5) && is.null(randomize)) {
    do_sample <- TRUE
  } else if ((n_group >= 5) && is.logical(randomize)) {
    do_sample <- randomize
  }
  
  if (do_sample) {
    group_color <- sample(group_color)
  }
  group_color
}

euclidian = function(values){
  # simple euclidian distance function to transform correlations to distances
  return(sqrt(2*(1 - values)))
}

#' cluster and reorder
#' 
#' given a matrix (maybe a distance matrix), cluster and then re-order using
#' dendsort.
#' 
#' @param similarity_matrix matrix of similarities
#' @param matrix_indices indices to reorder
#' @param transform should a transformation be applied to the data first
#' @param hclust_method which method for clustering should be used?
#' @param dendsort_type how should the reordering be done? (default is "min")
#' 
#' @import dendsort
#' @importFrom stats as.dist hclust as.dendrogram
#' @export
#' 
#' @return a \link{dendrogram} object. To get the order use \code{order.dendogram}.
similarity_reorder <- function(similarity_matrix, matrix_indices=NULL, transform = "none",
                               hclust_method = "complete",
                               dendsort_type = "min"){
  if (is.null(matrix_indices)){
    matrix_indices <- seq(1, nrow(similarity_matrix))
  }
  
  if (!inherits(similarity_matrix, "dist")){
    similarity_matrix <- as.dist(similarity_matrix)
  }
  
  transform_data <- switch(transform,
                           none = similarity_matrix,
                           inverse = 1 / similarity_matrix,
                           sub_1 = 1 - similarity_matrix,
                           log = log(similarity_matrix),
                           euclidian = euclidian(similarity_matrix))
  
  if (min(transform_data, na.rm = TRUE) < 0){
    transform_data <- transform_data - min(transform_data)
  }
  
  tmp_clust <- as.dendrogram(hclust(transform_data, method = hclust_method))
  new_sort <- dendsort::dendsort(tmp_clust, type = dendsort_type)
  return(list(dendrogram = new_sort, indices = matrix_indices[order.dendrogram(new_sort)]))
  #matrix_indices[order.dendrogram(new_sort)]
}


#' reorder by sample class
#' 
#' to avoid spurious visualization problems, it is useful in a heatmap visualization
#' to reorder the samples within each sample class. This function uses 
#' hierarchical clustering and \link{dendsort} to sort entries in a distance matrix.
#' 
#' @param similarity_matrix matrix of similarities between objects
#' @param sample_classes data.frame or factor denoting classes
#' @param transform a transformation to apply to the data
#' @param hclust_method which method for clustering should be used
#' @param dendsort_type how should dendsort do reordering?
#' 
#' @details 
#' 
#' The \code{similarity_matrix} should be either a square matrix of similarity values
#' or a distance matrix of class \code{dist}. If your matrix does not encode a "true"
#' distance, you can use a \code{transform} to turn it into a true \code{distance}
#' (for example, if you have correlation, then a distance would be 1 - correlation,
#' use "sub_1" as the transform argument).
#' 
#' The \code{sample_classes} should be either a data.frame or factor argument. If 
#' a data.frame is passed, all columns of the data.frame will be pasted together
#' to create a factor for splitting the data into groups. If the rownames of the
#' data.frame do not correspond to the rownames or colnames of the matrix, then
#' it is assumed that the ordering in the matrix and the data.frame are identical.
#' 
#' @import dendsort
#' @export
#' 
#' @return a list containing the reordering of the matrix in a:
#'   \enumerate{
#'     \item dendrogram
#'     \item numeric vector
#'     \item character vector (will be NULL if rownames are not set on the matrix)
#'   }
#' 
#' @examples 
#' library(visualizationQualityControl)
#' set.seed(1234)
#' mat <- matrix(rnorm(100, 2, sd = 0.5), 10, 10)
#' rownames(mat) <- colnames(mat) <- letters[1:10]
#' neworder <- similarity_reorderbyclass(mat)
#' mat[neworder$indices, neworder$indices]
#'
#' sample_class <- data.frame(grp = rep(c("grp1", "grp2"), each = 5), stringsAsFactors = FALSE)
#' rownames(sample_class) <- rownames(mat)
#' neworder2 <- similarity_reorderbyclass(mat, sample_class[, "grp", drop = FALSE])
#' 
#' # if there is a class with only one member, it is dropped, with a warning
#' sample_class[10, "grp"] = "grp3"
#' neworder3 <- similarity_reorderbyclass(mat, sample_class[, "grp", drop = FALSE])
#' neworder3$indices # 10 should be missing
#' 
#' mat[neworder2$indices, neworder2$indices]
#' cbind(neworder$names, neworder2$names)
#' 
similarity_reorderbyclass <- function(similarity_matrix, sample_classes=NULL, transform="none",
                                      hclust_method = "complete",
                                      dendsort_type = "min"){
  num_indices <- seq(1, nrow(similarity_matrix))
  
  stopifnot(identical(rownames(similarity_matrix), colnames(similarity_matrix)))
  
  matrix_names <- rownames(similarity_matrix)
  
  if (is.null(sample_classes)){
    sample_classes <- data.frame(none = rep(1, length(num_indices)))
    
    if (!is.null(matrix_names)){
      rownames(sample_classes) <- matrix_names
    }
  }
  
  # transform factor to data.frame because easier to work with one
  # structure later on. Notice that we bet that names of a factor will
  # become the rownames of the data.frame
  if (is.factor(sample_classes)){
    sample_classes <- data.frame(none = sample_classes)
  }
  
  # if the rownames are simply 1-x, then change them to match
  # the matrix rownames so that our checks later work right
  if (identical(rownames(sample_classes), as.character(seq(1, nrow(similarity_matrix))))){
    rownames(sample_classes) <- rownames(similarity_matrix)
  }
  
  class_names <- rownames(sample_classes)
  # check if the names are the same, and in the same order, because we are not
  # going to attempt anything otherwise, because all of the heatmap stuff (that
  # we mostly use this for) depend on it. Note that we set the rownames and colnames
  # on the matrix if they are missing so the dendrogram has something useful
  # on it!
  if (!is.null(matrix_names)){
    if (!identical(matrix_names, class_names)){
      stop("similarity_matrix and sample_classes rownames must match!", call. = FALSE)
    }
  } else {
    rownames(similarity_matrix) <- colnames(similarity_matrix) <- num_indices
  }
  
  # we use ALL of the columns to generate factors that are used for splitting!
  if (ncol(sample_classes) > 1) {
    use_class <- do.call(paste, c(sample_classes, sep="."))
  } else {
    use_class <- sample_classes
  }
  
  
  split_indices <- split(num_indices, use_class)
  n_indices <- lapply(split_indices, function(x){
    length(x)
  })
  keep_indices <- n_indices > 1
  
  if (sum(!keep_indices) > 0) {
    warning(paste0("Removing groups: ", paste(names(split_indices)[!keep_indices], collapse = ", ")))
  }
  
  
  new_order <- lapply(split_indices[keep_indices], function(x){
    similarity_reorder(similarity_matrix[x, x], x, transform = transform,
                       hclust_method = hclust_method,
                       dendsort_type = dendsort_type)
  })
  
  out_dendrogram <- new_order[[1]][["dendrogram"]]
  
  if (length(new_order) > 1){
    for (id in seq(2, length(new_order))){
      out_dendrogram <- merge(out_dendrogram, new_order[[id]][["dendrogram"]], adjust = "add.max")
    }
  }
  
  out_indices <- unlist(lapply(new_order, function(x){x$indices}), use.names = FALSE)
  out_names <- NULL
  
  if (!is.null(matrix_names)){
    out_names <- matrix_names[out_indices]
  }
  
  return(list(dendrogram = out_dendrogram, indices = out_indices, names = out_names))
}


#' easier heatmaps
#' 
#' rolls some of the common \code{Heatmap} options into a single function call
#' to make life easier when creating lots of heatmaps. \strong{Note:} clustering
#' of rows and columns is disabled, it is expected that you are reordering the
#' matrix beforehand, or passing in \code{column_order} and \code{row_order} as
#' arguments to be passed to \code{Heatmap} (see example). Matrices can be reordered
#' using \code{\link{similarity_reorderbyclass}}, and nice class colors generated
#' using \code{\link{generate_group_colors}}
#' 
#' @param matrix_data the matrix you want to plot as a heatmap
#' @param color_values the color mapping of values to colors (see Details)
#' @param title what do the values represent
#' @param row_color_data data for row annotations
#' @param row_color_list list for row annotations
#' @param col_color_data data for column annotations
#' @param col_color_list list for column annotations
#' @param ... other \code{Heatmap} parameters
#' 
#' @details This function uses the \code{ComplexHeatmap} package to produce
#' heatmaps with complex row- and column-color annotations. Both \code{row_color_data}
#' and \code{col_color_data} should be \code{data.frame}'s where each column describes
#' meta-data about the rows or columns of the matrix. The \code{row_color_list} and 
#' \code{col_color_list} provide the mapping of color to annotation, where each
#' \code{list} entry should be a named vector of colors, with the list entry
#' corresponding to a column entry in the data.frame, and the names of the colors
#' corresponding to annotations in that column.
#' 
#' @examples  
#' \dontrun{
#' library(circlize)
#' data(grp_cor)
#' data(grp_info)
#' colormap <- colorRamp2(c(0, 1), c("black", "white"))
#' 
#' annotation_color <- c(grp1 = "green", grp2 = "red", set1 = "blue",
#'                       set2 = "yellow")
#' 
#' row_data <- grp_info[, "grp", drop = FALSE]
#' col_data <- grp_info[, "set", drop = FALSE]
#' row_annotation = list(grp = annotation_color[1:2])
#' col_annotation = list(set = annotation_color[3:4])
#' 
#' visqc_heatmap(grp_cor, colormap, row_color_data = row_data, row_color_list = row_annotation,
#'                  col_color_data = col_data, col_color_list = col_annotation)
#'                  
#' reorder_sim <- similarity_reorderbyclass(grp_cor, transform = "sub_1")
#' visqc_heatmap(grp_cor, colormap, "reorder1", row_data, row_annotation, col_data, col_annotation,
#'                  column_order = reorder_sim$indices, row_order = reorder_sim$indices)
#' 
#' sample_classes <- grp_info[, "grp", drop = FALSE]
#' reorder_sim2 <- similarity_reorderbyclass(grp_cor, sample_classes, "sub_1")
#' visqc_heatmap(grp_cor, colormap, "reorder2", row_data, row_annotation, col_data, col_annotation,
#'                  column_order = reorder_sim2$indices, row_order = reorder_sim2$indices)
#' }
#' 
#' @import ComplexHeatmap
#' @export
visqc_heatmap <- function(matrix_data, color_values, title = "", row_color_data = NULL, row_color_list = NULL, col_color_data = NULL, col_color_list = NULL, ...){
  if (!is.null(row_color_data) && !is.null(row_color_list)){
    row_annot <- rowAnnotation(df = row_color_data, col = row_color_list)
  } else{
    row_annot = NULL
  }
  if (!is.null(col_color_data) && !is.null(col_color_list)){
    if (!is.null(row_color_data) && !is.null(row_color_list)) {
      col_annot <- HeatmapAnnotation(df = col_color_data, col = col_color_list, show_legend = FALSE)
    } else {
      col_annot <- HeatmapAnnotation(df = col_color_data, col = col_color_list)
    }
  } else{
    col_annot <- NULL
  }
  
  heat_out <- Heatmap(matrix_data, col = color_values,
                      top_annotation = col_annot, column_title = title, 
                      cluster_rows = FALSE, cluster_columns = FALSE, ...) + row_annot
  heat_out
}
