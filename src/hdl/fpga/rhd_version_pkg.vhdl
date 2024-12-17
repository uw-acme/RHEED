----------------------------------------------------------------------------------------
-- Project       : RHEED
-- File          : rhd_version_pkg.vhd
-- Description   : Version package file.
-- Author        : gjones
----------------------------------------------------------------------------------------
library ieee;
use     ieee.std_logic_1164.all;

package rhd_version_pkg is

----------------------------------------------------------------------------------------
--  Constants 
----------------------------------------------------------------------------------------
-- 0x0001     : First version. 
----------------------------------------------------------------------------------------
constant C_RHD_VERSION      : std_logic_vector(31 downto 0) := X"00000001";     -- HDL Version


end package rhd_version_pkg;

