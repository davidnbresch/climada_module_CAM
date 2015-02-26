# climada_module_CAM

climada module to deal with high-resolution tropical cyclone resolving climate simulations

In order to grant core climada access to additional modules, create a folder ‘climada_modules’ on the same level as the core climada folder and copy/move any additional modules into climada_modules (with or without 'climada_module_' in the filename). 

E.g. if the addition module is named climada_module_MODULE_NAME, we should have
.../climada the core climada, with sub-folders as
.../climada/code
.../climada/data
.../climada/docs
and then
.../climada_modules/MODULE_NAME with contents such as 
.../climada_modules/MODULE_NAME/code
.../climada_modules/MODULE_NAME/data
.../climada_modules/MODULE_NAME/docs
this way, climada sources all modules' code upon startup

see climada/docs/climada_manual.pdf to get started

copyright (c) 2015, David N. Bresch, david.bresch@gmail.com and Andrew Gettelman, andrew@ucar.edu, all rights reserved.
