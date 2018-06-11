program qml_driver

    implicit none

    double precision, allocatable, dimension(:,:) :: Q
    double precision, allocatable, dimension(:):: Y
    
    double precision :: sigma
    integer :: rep_size
    integer :: n_molecules

    double precision, allocatable, dimension(:,:) :: b
    double precision, allocatable, dimension(:) :: alphas

    integer :: m, n, nrhs, lda, ldb, info
    integer :: na
    integer :: i, j

    integer :: lwork
    double precision, dimension(:), allocatable :: work
    double precision, dimension(:,:), allocatable :: K 

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

    ! Allocate kernel
    allocate(K(na,na))

    ! Calculate Laplacian kernel
    do i = 1, na
        do j = 1, na
            K(j,i) = exp(-sum(abs(Q(j,:) - Q(i,:)))/sigma)
        enddo
    enddo

    ! Setup variables for LAPACK
    m = size(K, dim=1)
    n = size(K, dim=2)
    nrhs = 1
    lda = m
    ldb = max(m,n)
    allocate(b(ldb,1))
    b = 0.0d0
    b(:m,1) = y(:m)
    lwork = (min(m,n) + max(m,n)) * 10
    allocate(work(lwork))

    ! Solver
    call dgels("N", m, n, nrhs, K, lda, b, ldb, work, lwork, info)

    ! Copy LAPACK output
    alphas(:n) = b(:n,1)
   
    ! Save alphas to file
    open(unit = 9, file = "alphas_mpi.fout", form="formatted")
        write(9,*) alphas(:)
    close(9)
   
    ! Clean up 
    deallocate(work)
    deallocate(b)
    deallocate(Q)
    deallocate(K)
    deallocate(Y)    
    deallocate(alphas)    

end program qml_driver
