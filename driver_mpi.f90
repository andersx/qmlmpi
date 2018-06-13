program qml_driver
    use mpi
    implicit none

    double precision, allocatable, dimension(:,:) :: Q
    double precision, allocatable, dimension(:):: Y
    
    double precision :: sigma
    integer :: rep_size
    integer :: n_molecules

    double precision, allocatable, dimension(:) :: alphas

    integer :: info
    integer :: na, i, numroc
    integer :: local_i, local_j, global_i, global_j

    integer :: lwork
    double precision, dimension(:), allocatable :: work
    double precision, dimension(:,:), allocatable :: local_K, local_B

    ! pblacs data structures
    integer :: local_K_rows, local_K_cols
    integer :: local_B_rows, local_B_cols
    integer :: local_id, num_ranks, ranks_rows, ranks_cols, context
    integer :: local_rank_col, local_rank_row, block_size
    integer :: ierr
    integer, dimension(9) :: desca, descb
    integer, dimension(2) :: dims
    double precision, dimension(2) :: work_query
    
    ! init pblacs and set cartesian grid of MPI ranks
    call blacs_pinfo(local_id, num_ranks)

    dims = 0
    call MPI_Dims_create(num_ranks, 2, dims, ierr)
    ranks_rows = dims(1)
    ranks_cols = dims(2)

    block_size = 100

    ! create BLACS context
    call blacs_get(0, 0, context)
    call blacs_gridinit(context, 'R', ranks_rows, ranks_cols)
    call blacs_gridinfo(context, ranks_rows, ranks_cols, &
        local_rank_row, local_rank_col)

    ! Read hyperparameters and arrat suzes
    open(unit = 9, file = "parameters.fout", form="formatted")

        read(9,*) sigma, rep_size, n_molecules

        ! Allocate labels
        allocate(Y(n_molecules))

        read(9,*) Y(:n_molecules)

    close(9)
    
    ! allocate alphas
    allocate(alphas(n_molecules))
    ! Allocate representations
    allocate(Q(n_molecules, rep_size))

    ! Read representations
    open(unit = 9, file = "representations.fout", form="formatted")
        
        ! Read representaions for each molecule
        do i = 1, n_molecules 
            read(9,*) Q(i,:rep_size)
        enddo

    close(9)

    ! Size of kernel
    na = size(Q, dim=1)

    ! Allocate kernel and output
    local_K_rows = numroc(na, block_size, local_rank_row, 0, ranks_rows)
    local_K_cols = numroc(na, block_size, local_rank_col, 0, ranks_cols)
    allocate(local_K(local_K_rows, local_K_cols))
    local_B_rows = numroc(na, block_size, local_rank_row, 0, ranks_rows)
    local_B_cols = numroc(1, block_size, local_rank_col, 0, ranks_cols)
    allocate(local_B(local_B_rows, local_B_cols))

    ! Calculate Laplacian kernel
    do local_j = 1, local_K_cols
        call l2g(local_j, local_rank_col, ranks_cols, &
                block_size, global_j)
        do local_i = 1, local_K_rows
            call l2g(local_i, local_rank_row, ranks_rows, &
                block_size, global_i)
            local_K(local_i, local_j) = exp(-sum(abs(Q(global_j,:) - Q(global_i,:)))/sigma)
        enddo
    enddo

    ! Setup variables for LAPACK
    call descinit(desca, na, na, block_size, block_size, 0, 0, context, local_K_rows, info)
    call descinit(descb, na, 1, block_size, block_size, 0, 0, context, local_B_rows, info)

    ! Allocate local work arrays
    call pdgels("N", na, na, 1, local_K, 1, 1, desca, local_B, 1, 1, DESCB, work_query, -1, info)
    lwork = INT(work_query(1))
    allocate(work(lwork))

    ! copy data
    local_B = 0.0d0
    do local_i = 1, local_B_rows
        call l2g(local_i, local_rank_row, ranks_rows, block_size, global_i)
        local_B(local_i, 1) = y(global_i)
    enddo

    ! Solver
    call pdgels("N", na, na, 1, local_K, 1, 1, desca, local_B, 1, 1, DESCB, work, lwork, info)

    ! Copy LAPACK output
    alphas = 0.0d0
    do local_i = 1, local_B_rows
        call l2g(local_i, local_rank_row, ranks_rows, block_size, global_i)
        alphas(global_i) = local_B(local_i, 1)
    enddo
    call DGSUM2D(context, "All", "1-tree", na, 1, alphas, 1, -1, -1)

    ! Save alphas to file
    if (local_id .eq. 0) then
        open(unit = 9, file = "alphas_mpi.fout", form="formatted")
            write(9,*) alphas(:)
        close(9)
    end if
   
    ! Tear down MPI
    call blacs_exit(0)

    ! Clean up 
    deallocate(work)
    deallocate(local_B)
    deallocate(Q)
    deallocate(local_K)
    deallocate(Y)    
    deallocate(alphas)    

end program qml_driver
! convert local index to global index in block-cyclic distribution

   subroutine l2g(il,p,np,nb,i)

   implicit none
   integer :: il   ! local array index, input
   integer :: p    ! processor array index, input
   integer :: np   ! processor array dimension, input
   integer :: nb   ! block size, input
   integer :: i    ! global array index, output
   integer :: ilm1   

   ilm1 = il-1
   i    = (((ilm1/nb) * np) + p)*nb + mod(ilm1,nb) + 1

   return
   end subroutine l2g
