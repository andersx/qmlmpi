subroutine get_alphas(Q, Y, sigma, n_alphas, alphas)

    implicit none

    double precision, dimension(:,:), intent(in) :: Q
    double precision, dimension(:), intent(in):: Y
    integer, intent(in):: n_alphas
    double precision, intent(in):: sigma

    double precision, dimension(n_alphas), intent(out) :: alphas

    double precision, allocatable, dimension(:,:) :: b

    integer :: m, n, nrhs, lda, ldb, info
    integer :: na
    integer :: i, j

    integer :: lwork
    double precision, dimension(:), allocatable :: work
    double precision, dimension(:,:), allocatable :: K 

    write (*,*) size(Q, dim=1)
    write (*,*) size(Q, dim=2)

    na = size(Q, dim=1)

    allocate(K(na,na))

    do i = 1, na
        do j = 1, na
            K(j,i) = exp(-sum(abs(Q(j,:) - Q(i,:)))/sigma)
        enddo
    enddo


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

    call dgels("N", m, n, nrhs, K, lda, b, ldb, work, lwork, info)


    alphas(:n) = b(:n,1)
    
    deallocate(work)
    deallocate(b)

end subroutine get_alphas


subroutine write_input(Q, Y, sigma)

    implicit none

    double precision, dimension(:,:), intent(in) :: Q
    double precision, dimension(:), intent(in):: Y
    double precision, intent(in):: sigma

    integer :: rep_size
    integer :: n_molecules

    integer :: i

    n_molecules = size(Q, dim=1)
    rep_size = size(Q, dim=2)

    open(unit = 9, file = "parameters.fout", form="formatted")

    write (9,*) sigma, rep_size, n_molecules
    write (9,*) Y(:n_molecules)
    close(9)

    open(unit = 9, file = "representations.fout", form="formatted")
    
    do i=1, n_molecules
        
        write(9,*) Q(i,:rep_size)

    enddo

    close(9)

end subroutine write_input
