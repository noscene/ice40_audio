<?php
	
	for ($i = 0 ; $i < 256 ; $i++){
		$s16 = (int)((sin ($i * M_PI / 512  )  ) * 256 * 0xff );
		$hex = sprintf("%04x" ,$s16 );
		echo $hex."\n";
	}

