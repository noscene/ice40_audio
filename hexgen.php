<?php
	
	for ($i = 0 ; $i < 256 ; $i++){
		$s16 = (int)((sin ($i * M_PI / 128  ) + 1.0 ) * 32 * 0xff );
		$hex = sprintf("%04x" ,$s16 );
		echo $hex."\n";
	}

