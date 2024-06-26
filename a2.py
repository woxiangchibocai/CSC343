"""CSC343 Assignment 2

=== CSC343 Winter 2024 ===
Department of Computer Science,
University of Toronto

This code is provided solely for the personal and private use of
students taking the CSC343 course at the University of Toronto.
Copying for purposes other than this use is expressly prohibited.
All forms of distribution of this code, whether as given or with
any changes, are expressly prohibited.

Authors: Diane Horton, Marina Tawfik, Jacqueline Smith

All of the files in this directory and all subdirectories are:
Copyright (c) 2024 Diane Horton and Jacqueline Smith

=== Module Description ===

This file contains the Library class and some simple testing functions.
"""
import psycopg2 as pg
import psycopg2.extensions as pg_ext
import psycopg2.extras as pg_extras
from typing import Optional, List
import subprocess
from datetime import datetime, timedelta


class Library:
    """A class that can work with data conforming to the schema
    in a2_library_schema.ddl.

    === Instance Attributes ===
    connection: connection to a PostgreSQL database of a library management
    system.

    Representation invariants:
    - The database to which connection is established conforms to the schema
      in a2_library_schema.ddl.
    """
    connection: Optional[pg_ext.connection]

    def __init__(self):
        """Initialize this Library instance, with no database connection yet.
        """
        self.connection = None

    def connect(self, dbname: str, username: str, password: str) -> bool:
        """Establish a connection to the database <dbname> using the
        username <username> and password <password>, and assign it to the
        instance attribute 'connection'. In addition, set the search path
        to library, public.

        Return True if the connection was made successfully, False otherwise.
        I.e., do NOT throw an error if making the connection fails.

        >>> ww = Library()
        >>> # The following example will only work if you change the dbname
        >>> # and password to your own credentials.
        >>> ww.connect("postgres", "postgres", "password")
        True
        >>> # In this example, the connection cannot be made.
        >>> ww.connect("invalid", "nonsense", "incorrect")
        False
        """
        try:
            self.connection = pg.connect(
                dbname=dbname, user=username, password=password,
                options="-c search_path=Library,public"
            )
            return True
        except pg.Error:
            return False

    def disconnect(self) -> bool:
        """Close the database connection.

        Return True if closing the connection was successful, False otherwise.
        I.e., do NOT throw an error if closing the connection failed.

        >>> a2 = Library()
        >>> # The following example will only work if you change the dbname
        >>> # and password to your own credentials.
        >>> a2.connect("postgres", "postgres", "password")
        True
        >>> a2.disconnect()
        True
        """
        try:
            if self.connection and not self.connection.closed:
                self.connection.close()
            return True
        except pg.Error:
            return False

    def search(self, last_name: str, branch: str) -> List[str]:
        """Return the titles of all holdings at the library with the unique code
        <branch>, by any contributor with the last name <last_name>.
        Return an empty list if no matches are found.
        If two different holdings happen to have the same title, return both
        titles.
        However, don't return the same holding twice.

        Your method must NOT throw an error. Return an empty list if an error
        occurs.
        """
        try:
            cursor = self.connection.cursor()
            query = """
            SELECT DISTINCT a1.title
            FROM Holding a1
            INNER JOIN HoldingContributor a2 ON a1.id = a2.holding
            INNER JOIN Contributor a3 ON a2.contributor = a3.id
            INNER JOIN LibraryCatalogue a4 ON a1.id = a4.holding
            INNER JOIN LibraryBranch a5 ON a4.library = a5.code
            WHERE a3.last_name = %s AND a5.code = %s;
            """
            cursor.execute(query, (last_name, branch))
            title = []
            records = cursor.fetchall()
            for record in records:
                title.append(record[0])
            return title
        except pg.Error as ex:
            return []
        finally:
            cursor.close()
        
        

    def register(self, card_number: str, event_id: int) -> bool:
        """Record the registration of the patron with the card number
        <card_number> signing up for the event identified by <event_id>.

        Return True iff
            (1) The card number and event ID provided are both valid
            (2) This patron is not already registered for this event
            (3) The patron is not already registered for an event that overlaps
        Otherwise, return False.
        
        Two events that are consecutive, e.g. one ends at 14:00:00 and the 
        other begins at 14:00:00, are not considered overlapping. 

        Return True if the operation was successful (as per the above criteria),
        and False otherwise. Your method must NOT throw an error.
        """
        try: 
            cursor = self.connection.cursor()
            query1 = "SELECT EXISTS(SELECT 1 FROM Patron WHERE card_number = %s)"
            cursor.execute(query1,(card_number,))
            if not cursor.fetchone()[0]:
                return False
            query2 = "SELECT EXISTS(SELECT 1 FROM LibraryEvent WHERE id = %s)"
            cursor.execute(query2,(event_id,))
            if not cursor.fetchone()[0]:
                return False
            query3 = "SELECT EXISTS(SELECT 1 FROM EventSignUp WHERE patron = %s AND event = %s)"
            cursor.execute(query3,(card_number,event_id))
            if cursor.fetchone()[0]:
                return False
            query4 = '''
            SELECT COUNT(*)
            FROM EventSchedule a1
            JOIN EventSignUp a2 ON a1.event != a2.event
            JOIN EventSchedule a3 ON a2.event =a3.event
            WHERE a2.patron = %s
            AND a1.event = %s
            AND a1.edate = a3.edate
            AND NOT(a1.end_time <= a3.start_time OR a1.start_time >= a3.end_time)
            '''
            cursor.execute(query4,(card_number,event_id))
            if cursor.fetchone()[0] != 0:
                return False
            query5 = "INSERT INTO EventSignUp (patron, event) VALUES (%s, %s)"
            cursor.execute(query5,(card_number,event_id))
            return True
        
        except pg.Error as ex:
            return False
        finally:
            cursor.close()

    def return_item(self, checkout: int) -> float:
        """Record that the checked-out library item, with the checkout id
        <checkout> was returned at the current time and return the fines 
        incurred on that item.

        Use the same due date rules as the SQL queries.

        The fines incurred are calculated as follows: for everyday overdue
        i.e. past the due date:
            books and audiobooks incur a $0.50 charge
            other holding types incur a $1.00 charge

        A return operation is considered successful iff all the following
        criteria are satisfied:
            (1) The checkout id checkout provided is valid.
            (2) A return has not already been recorded for this checkout.
            (3) Updating the LibraryCatalogue won't cause the number of
                available copies to exceed the number of holdings.

        If the return operation is successful, make all necessary modifications
        (indicated above) and return the amount of fines incurred.
        Otherwise, the db instance should NOT be modified at all and a value of
        -1.0 should be returned. Your method must NOT throw an error.
        """
        try:
            cursor = self.connection.cursor()
            query1 = "SELECT EXISTS(SELECT 1 FROM Checkout WHERE id = %s)"
            cursor.execute(query1,(checkout,))
            if not cursor.fetchone()[0]:
                return -1
            
            query2 = """
            SELECT a1.checkout_time, a4.htype
            FROM Checkout a1
            JOIN LibraryHolding a3 ON a3.barcode = a1.copy
            LEFT JOIN Return a2 ON a1.id = a2.checkout
            JOIN Holding a4 ON a3.holding = a4.id
            WHERE a1.id = %s and a2.checkout is NULL;
            """
            cursor.execute(query2, (checkout,))
            records = cursor.fetchall()
            for record in records:
                checkout_time = record[0]
                htype = record[1]
                if htype == 'books' or htype == 'audiobooks':
                    due_date = checkout_time + timedelta(days=21)
                    current_time = datetime.now()
                    overdue_days = (current_time.date() - due_date.date()).days
                    if overdue_days <= 0:
                        fine = 0.0
                    else:
                        fine = 0.5 * overdue_days
                else:
                    due_date = checkout_time + timedelta(days=7)
                    current_time = datetime.now()
                    overdue_days = (current_time.date() - due_date.date()).days
                    if overdue_days <= 0:
                        fine = 0.0
                    else:
                        fine = 1.0 * overdue_days
            return_query = """
            INSERT INTO Return (checkout, return_time) VALUES (%s, CURRENT_TIMESTAMP);
            """
            cursor.execute(return_query, (checkout,))          
            return fine
        except pg.Error as ex:
            return -1
        finally:
            cursor.close()
        



def test_preliminary() -> None:
    """Test preliminary aspects of the A2 methods.
    
    We have provided this function to you to give you some examples of what
    testing your code could look like. You should do much more thorough testing
    yourself before submitting to make sure your code works correctly. 
    """
    # TODO: Change the values of the following variables to connect to your
    #  own database:
    dbname = "csc343h-userid"
    user = "userid"
    password = ""

    a2 = Library()
    try:
        connected = a2.connect(dbname, user, password)

        # The following is an assert statement. It checks that the value for
        # connected is True. The message after the comma will be printed if
        # that is not the case (connected is False).
        # Use the same notation to thoroughly test the methods we have provided
        assert connected, f"[Connect] Expected True | Got {connected}."

        # TODO: Test one or more methods here, or better yet, make more testing
        #   functions, with each testing a different aspect of the code.

        # The following function will set up the testing environment by loading
        # a fresh copy of the schema and the sample data we have provided into
        # your database. You can create more sample data files and use the same
        # function to load them into your database.

        # ------------------------- Testing search ----------------------------#

        expected_titles = ["Willy Wonka and the chocolate factory"]
        returned_titles = a2.search("Stuart", "DM")
        # We don't really need to use set here, but you might find it useful
        # in your own testing since we don't care about the order of the
        # returned items.
        assert set(returned_titles) == set(expected_titles), \
            f"[Search] Expected:\n{expected_titles}\n Got:\n{returned_titles}"

        # ------------------------ Testing register ---------------------------#

        # Invalid card number, valid event id
        # You should also check that no modifications were made to the db
        registered = a2.register("1", 100)
        assert not registered, "[Register] Invalid card number, valid " \
                               "event id: should return False. " \
                               f"Returned {registered}"
        # Valid card number, Invalid event id
        # You should also check that no modifications were made to the db
        registered = a2.register("5309015788", 200)
        assert not registered, "[Register] Valid card number, Invalid " \
                               "event id: should return False. " \
                               f"Returned {registered}"
        # Valid card number and event id
        # You should also check that the following row has been added to
        # the EventSignup relation:
        #   ("02953575718", 77)
        registered = a2.register("02953575718", 77)
        assert registered, "[Register] Valid card number, valid event id: " \
                           f"should return True. Returned {registered}"

        # ----------------------- Testing return_item -------------------------#

        # Invalid checkout id
        # You should also check that no modifications were made to the db
        returned = a2.return_item(2020)
        assert returned == -1.0, "[Return] Invalid checkout id:" \
                                 f"should return -1.0. Returned {returned}"

        # Valid checkout id, but has already been returned
        returned = a2.return_item(94)
        assert returned == -1.0, "[Return] Already returned checkout id:" \
                                 f"should return -1.0. Returned {returned}"

    finally:
        a2.disconnect()


if __name__ == '__main__':
    # Un comment-out the next two lines if you would like to run the doctest
    # examples (see ">>>" in the methods connect and disconnect)
    # import doctest
    # doctest.testmod()

    # TODO: Put your testing code here, or call testing functions such as
    #   this one:
    test_preliminary()
