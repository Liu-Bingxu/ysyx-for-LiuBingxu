package dm_pkg;

localparam DEBUG_ROM_START        = 12'h800;
localparam DEBUG_FLAG_START       = 12'h400;
localparam DEBUG_DATA_START       = 12'h380;
localparam DEBUG_PROGBUF_START    = 12'h340;
// localparam DEBUG_ABSTRACT_START   = 12'h310;
localparam DEBUG_ROM_WHERETO      = 12'h300;
localparam DEBUG_EXCEPTION_START  = 12'h10C;
localparam DEBUG_RESUMING_START   = 12'h108;
localparam DEBUG_GOING_START      = 12'h104;
localparam DEBUG_HALT_START       = 12'h100;

endpackage
