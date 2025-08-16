module library_ledger::LibraryLending {

    // This module uses a named address 'library_ledger'.
    // To compile, you must provide a value for this address using the --named-addresses flag.
    // Example compilation command:
    // aptos move compile --named-addresses library_ledger=0xYOUR_ACCOUNT_ADDRESS

    use std::signer;
    use std::table;
    use aptos_framework::coin;
    use aptos_framework::aptos_coin::AptosCoin;

    /// A struct representing a single book.
    struct Book has key, store, drop {
        is_available: bool,
        borrower: address,
        deposit_amount: u64,
    }

    /// The main resource for the library, owned by a single account.
    struct Library has key {
        books: table::Table<u64, Book>,
    }

    /// Creates a new library resource and moves it to the account.
    public fun create_library(owner: &signer) {
        move_to(owner, Library {
            books: table::new<u64, Book>(),
        });
    }

    /// Borrows a book, requiring the specified deposit amount.
    public fun borrow_book(
        library_owner: address,
        borrower: &signer,
        book_id: u64,
        deposit: u64
    ) acquires Library {
        let library_ref = borrow_global_mut<Library>(library_owner);

        let book_ref = table::borrow_mut(&mut library_ref.books, book_id);

        // Check if the book is available and the deposit is correct.
        assert!(book_ref.is_available, 0); // EBookNotAvailable
        assert!(deposit == book_ref.deposit_amount, 1); // EIncorrectDeposit

        // Transfer the deposit from the borrower to the library owner.
        let deposit_coin = coin::withdraw<AptosCoin>(borrower, deposit);
        coin::deposit<AptosCoin>(library_owner, deposit_coin);

        // Update the book's state.
        book_ref.is_available = false;
        book_ref.borrower = signer::address_of(borrower);
    }

    /// Returns a book and refunds the deposit. This function must be called by the library owner.
    public fun return_book(
        library_owner: &signer, // The owner is now a signer to authorize the refund.
        borrower: address, // The borrower's address to send the refund to.
        book_id: u64,
    ) acquires Library {
        let library_ref = borrow_global_mut<Library>(signer::address_of(library_owner));

        let book_ref = table::borrow_mut(&mut library_ref.books, book_id);

        // Check if the book is currently borrowed and if the correct borrower is specified.
        assert!(!book_ref.is_available, 2); // EBookNotBorrowed
        assert!(borrower == book_ref.borrower, 3); // ENotTheBorrower

        // Transfer the deposit back from the library owner to the borrower.
        let deposit_coin = coin::withdraw<AptosCoin>(library_owner, book_ref.deposit_amount);
        coin::deposit<AptosCoin>(borrower, deposit_coin);

        // Reset the book's state.
        book_ref.is_available = true;
        book_ref.borrower = @0x0;
    }

    // A helper function to add a book (not part of the 2-function requirement).
    // To be used by the library owner to populate the table.
    public fun add_book(owner: &signer, book_id: u64, deposit_amount: u64) acquires Library {
        let library_ref = borrow_global_mut<Library>(signer::address_of(owner));
        let new_book = Book { is_available: true, borrower: @0x0, deposit_amount };
        table::add(&mut library_ref.books, book_id, new_book);
    }
}
