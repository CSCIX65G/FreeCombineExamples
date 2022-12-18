//
//  Errors.swift
//  
//
//  Created by Van Simmons on 12/16/22.
//

struct MergeCancellationFailureError: Error { let id: Int }
struct ZipCancellationFailureError: Error { }
struct SelectCancellationFailureError: Error { }
struct ConnectableCompletionError: Error { }
