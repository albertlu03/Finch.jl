@inbounds begin
        C = ex.body.lhs.tns.tns
        A_lvl = (ex.body.rhs.args[1]).tns.tns.lvl
        A_lvl_pos_alloc = length(A_lvl.pos)
        A_lvl_idx_alloc = length(A_lvl.idx)
        A_lvl_2 = A_lvl.lvl
        A_lvl_2_val_alloc = length(A_lvl.lvl.val)
        A_lvl_2_val = 0.0
        B_lvl = (ex.body.rhs.args[2]).tns.tns.lvl
        B_lvl_pos_alloc = length(B_lvl.pos)
        B_lvl_idx_alloc = length(B_lvl.idx)
        B_lvl_2 = B_lvl.lvl
        B_lvl_2_val_alloc = length(B_lvl.lvl.val)
        B_lvl_2_val = 0.0
        (C_mode1_stop,) = size(C)
        i_stop = C_mode1_stop
        (C_mode1_stop,) = size(C)
        1 == 1 || throw(DimensionMismatch("mismatched dimension start"))
        C_mode1_stop == C_mode1_stop || throw(DimensionMismatch("mismatched dimension stop"))
        fill!(C, 0)
        A_lvl_q = A_lvl.pos[1]
        A_lvl_q_stop = A_lvl.pos[1 + 1]
        if A_lvl_q < A_lvl_q_stop
            A_lvl_i = A_lvl.idx[A_lvl_q]
            A_lvl_i1 = A_lvl.idx[A_lvl_q_stop - 1]
        else
            A_lvl_i = 1
            A_lvl_i1 = 0
        end
        B_lvl_q = B_lvl.pos[1]
        B_lvl_q_stop = B_lvl.pos[1 + 1]
        if B_lvl_q < B_lvl_q_stop
            B_lvl_i = B_lvl.idx[B_lvl_q]
            B_lvl_i1 = B_lvl.idx[B_lvl_q_stop - 1]
        else
            B_lvl_i = 1
            B_lvl_i1 = 0
        end
        i = 1
        i_start = i
        phase_start = max(i_start)
        phase_stop = min(B_lvl_i1, A_lvl_i1, i_stop)
        if phase_stop >= phase_start
            i = i
            i = phase_start
            while A_lvl_q < A_lvl_q_stop && A_lvl.idx[A_lvl_q] < phase_start
                A_lvl_q += 1
            end
            while B_lvl_q < B_lvl_q_stop && B_lvl.idx[B_lvl_q] < phase_start
                B_lvl_q += 1
            end
            while i <= phase_stop
                i_start_2 = i
                A_lvl_i = A_lvl.idx[A_lvl_q]
                B_lvl_i = B_lvl.idx[B_lvl_q]
                phase_start_2 = max(i_start_2)
                phase_stop_2 = min(phase_stop, B_lvl_i, A_lvl_i)
                if phase_stop_2 >= phase_start_2
                    i_2 = i
                    if A_lvl_i == phase_stop_2 && B_lvl_i == phase_stop_2
                        A_lvl_2_val = A_lvl_2.val[A_lvl_q]
                        B_lvl_2_val = B_lvl_2.val[B_lvl_q]
                        i_3 = phase_stop_2
                        C[i_3] = C[i_3] + (A_lvl_2_val + B_lvl_2_val)
                        A_lvl_q += 1
                        B_lvl_q += 1
                    elseif B_lvl_i == phase_stop_2
                        B_lvl_2_val = B_lvl_2.val[B_lvl_q]
                        i_4 = phase_stop_2
                        C[i_4] = C[i_4] + B_lvl_2_val
                        B_lvl_q += 1
                    elseif A_lvl_i == phase_stop_2
                        A_lvl_2_val = A_lvl_2.val[A_lvl_q]
                        i_5 = phase_stop_2
                        C[i_5] = C[i_5] + A_lvl_2_val
                        A_lvl_q += 1
                    else
                    end
                    i = phase_stop_2 + 1
                end
            end
            i = phase_stop + 1
        end
        i_start = i
        phase_start_3 = max(i_start)
        phase_stop_3 = min(A_lvl_i1, i_stop)
        if phase_stop_3 >= phase_start_3
            i_6 = i
            i = phase_start_3
            while A_lvl_q < A_lvl_q_stop && A_lvl.idx[A_lvl_q] < phase_start_3
                A_lvl_q += 1
            end
            while i <= phase_stop_3
                i_start_3 = i
                A_lvl_i = A_lvl.idx[A_lvl_q]
                phase_stop_4 = min(phase_stop_3, A_lvl_i)
                i_7 = i
                if A_lvl_i == phase_stop_4
                    A_lvl_2_val = A_lvl_2.val[A_lvl_q]
                    i_8 = phase_stop_4
                    C[i_8] = C[i_8] + A_lvl_2_val
                    A_lvl_q += 1
                else
                end
                i = phase_stop_4 + 1
            end
            i = phase_stop_3 + 1
        end
        i_start = i
        phase_start_5 = max(i_start)
        phase_stop_5 = min(B_lvl_i1, i_stop)
        if phase_stop_5 >= phase_start_5
            i_9 = i
            i = phase_start_5
            while B_lvl_q < B_lvl_q_stop && B_lvl.idx[B_lvl_q] < phase_start_5
                B_lvl_q += 1
            end
            while i <= phase_stop_5
                i_start_4 = i
                B_lvl_i = B_lvl.idx[B_lvl_q]
                phase_stop_6 = min(phase_stop_5, B_lvl_i)
                i_10 = i
                if B_lvl_i == phase_stop_6
                    B_lvl_2_val = B_lvl_2.val[B_lvl_q]
                    i_11 = phase_stop_6
                    C[i_11] = C[i_11] + B_lvl_2_val
                    B_lvl_q += 1
                else
                end
                i = phase_stop_6 + 1
            end
            i = phase_stop_5 + 1
        end
        i_start = i
        phase_stop_7 = i_stop
        i_12 = i
        i = phase_stop_7 + 1
        (C = C,)
    end