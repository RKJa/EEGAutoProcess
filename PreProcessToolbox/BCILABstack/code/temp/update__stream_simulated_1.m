[stream_simulated_1.buffer(:,1+mod(stream_simulated_1.smax:stream_simulated_1.smax+size(stream_simulated_1_chunk,2)-1,stream_simulated_1.buffer_len)),stream_simulated_1.smax] = deal(stream_simulated_1_chunk,stream_simulated_1.smax + size(stream_simulated_1_chunk,2));