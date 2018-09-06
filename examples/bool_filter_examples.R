# Examples showing equivalent operations using dplyr::filter and stringr::str_detect

# Simple match

bool_filter(iris, 'Species', 'set')
# iris %>% filter(str_detect(Species, 'set'))

# AND query

bool_filter(iris, 'Species', 'vir AND ver')
# iris %>% filter(str_detect(Species, 'vir') & str_detect(Species, 'ver'))

# OR query

bool_filter(iris, 'Species', 'vir OR ver')
# iris %>% filter(str_detect(Species, 'vir') | str_detect(Species, 'ver'))

# NOT query

bool_filter(iris, 'Species', '-set')
# iris %>% filter(!str_detect(Species, 'set'))

# Note piping is not yet supported, so the following will fail:
iris %>% bool_filter('Species', 'set')
